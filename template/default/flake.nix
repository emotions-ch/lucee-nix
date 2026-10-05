{
  description = "Lucee - Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    lucee-nix = {
      url = "github:emotions-ch/lucee-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            inputs.lucee-nix.overlays.default
          ];
        };

        lucee = pkgs.mkTomcatLucee { luceeJar = "lucee7-zero"; };

        startScript = pkgs.writeShellScriptBin "start-lucee" ''
          export CATALINA_HOME=${lucee}
          export CATALINA_BASE=./lucee-instance
          export JAVA_HOME=${pkgs.openjdk25}
          export CLASSPATH="$CATALINA_BASE/lib/*:$CATALINA_HOME/lib/*"

          if [ ! -f "$CATALINA_BASE/conf/server.xml" ]; then
            ${pkgs.lib.getExe initScript}
          else
            echo "Using existing Lucee instance at $CATALINA_BASE"
          fi

          if [ ! -f ${cfConfig.dataSources.${project}.host}.secret ]; then
            echo "${cfConfig.dataSources.${project}.host}.secret not found!"
          else
            echo ""
            echo "------ Warmup ------"
            echo ""
            mkdir -p $CATALINA_BASE/lucee-server/deploy
            cp -f ${cfConfigJSON} $CATALINA_BASE/lucee-server/deploy/.CFConfig.json

            # Copy all extensions to deploy folder
            ${pkgs.lib.concatMapStringsSep "\n            " (
              ext: "cp -f ${ext}/*.lex $CATALINA_BASE/lucee-server/deploy/"
            ) extensions}

            LUCEE_ENABLE_WARMUP=1 $CATALINA_BASE/bin/catalina.sh run
            echo ""
            echo "------ Warmup complete ------"
            echo ""

            DATASOURCE_SECRET=$(cat $PWD/${
              cfConfig.dataSources.${project}.host
            }.secret) $CATALINA_BASE/bin/catalina.sh run
          fi
        '';

        initScript = pkgs.writeShellScriptBin "init-lucee" ''
          export CATALINA_HOME=${lucee}
          export CATALINA_BASE=./lucee-instance

          if [ ! -f "$CATALINA_BASE/conf/server.xml" ]; then
            echo "Initializing Lucee instance directory at $CATALINA_BASE"

            mkdir -p "$CATALINA_BASE/"
            cp -r ${lucee}/** "$CATALINA_BASE/"

            mkdir -p "$CATALINA_BASE/webapps/"
            ln -sf "$PWD/wwwroot" $CATALINA_BASE/webapps/ROOT

            chmod -R u+w "$CATALINA_BASE"
          else
            echo "Lucee instance already exists at $CATALINA_BASE"
            echo "Use 'start-lucee' to start the server"
          fi
        '';

        project = "myproject";
        cfConfigJSON = pkgs.writeText ".CFConfig.json" "${builtins.toJSON cfConfig}";

        # https://docs.lucee.org/recipes/configuration.html
        cfConfig = {
          dataSources = {
            ${project} = {
              name = project;
              class = "org.postgresql.Driver";
              bundleName = "org.postgresql.jdbc";
              dsn = "jdbc:postgresql://{host}:{port}/{database}";
              username = "devuser";
              password = "\${DATASOURCE_SECRET}"; # database password must be placed in a file called `${host}.secret` eg. localhost.secret
              host = "localhost";
              database = project;
              port = "5432";
            };
          };
        };

        # production config for dockerImage
        # Inherit all database config from development except username, password, and host
        prodCfConfig = {
          dataSources = {
            ${project} = (
              cfConfig.dataSources.${project}
              // {
                username = "\${DATABASE_USERNAME}";
                password = "\${DATABASE_PASSWORD}";
                host = "\${DATABASE_HOST}";
                port = "\${DATABASE_PORT}";
              }
            );
          };
        };

        # to see all avialable extensions run:
        # nix eval github:emotions-ch/lucee-nix#lucee-extensions --apply builtins.attrNames
        extensions = [
          pkgs.luceeExtensions.org_postgresql_jdbc
          pkgs.luceeExtensions.image_extension
        ];

        dockerImage = pkgs.mkLuceeDockerImage {
          inherit
            lucee
            extensions
            project
            ;
          webapp = ./wwwroot; # folder containing your index.cfm
          cfConfig = prodCfConfig;

          # for GHCR integration
          name = "ghcr.io/example/${project}";
          imageConfig = {
            Labels = {
              "org.opencontainers.image.source" = "https://github.com/example/${project}";
            };
          };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "${project}-nix-dev";

          buildInputs = with pkgs; [
            openjdk25

            startScript
            initScript
          ];

          shellHook = ''
            echo "  start-lucee"
            echo ""
          '';
        };

        packages = {
          lucee = startScript;
          default = startScript;

          # Docker image for production deployment
          inherit dockerImage;
        };

        formatter = pkgs.nixfmt-tree;

        # `nix flake check`: formatting, plus (on linux) a NixOS VM test that
        # boots the image and asserts Lucee serves.
        checks = pkgs.mkLuceeChecks {
          src = ./.;
          name = project;
          image = if pkgs.stdenv.hostPlatform.isLinux then dockerImage else null;
        };
      }
    );
}
