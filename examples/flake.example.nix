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

        lucee = pkgs.mkTomcatLucee { };

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
            cp -f ${luceeManagerJson} $CATALINA_BASE/conf/lucee-manager.json
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
            cp -f ${luceeManagerJson} $CATALINA_BASE/conf/lucee-manager.json

          else
            echo "Lucee instance already exists at $CATALINA_BASE"
            echo "Use 'start-lucee' to start the server"
          fi
        '';

        project = "example";
        cfConfigJSON = pkgs.writeText ".CFConfig.json" "${builtins.toJSON cfConfig}";

        # https://docs.lucee.org/recipes/configuration.html
        cfConfig = {
          dataSources = {
            ${project} = {
              name = project;
              class = "com.microsoft.sqlserver.jdbc.SQLServerDriver";
              bundleName = "org.lucee.mssql";
              dsn = "jdbc:sqlserver://{host}:{port}";
              id = "mssql";
              username = "username";
              password = "\${DATASOURCE_SECRET}"; # database password must be placed in a file called `${host}.secret` eg. db.test.emotions.ch.secret
              host = "db.test.example.com";
              database = "${project}";

              port = "1433";
              connectionLimit = "-1";
              connectionTimeout = "10";
              liveTimeout = "15";

              metaCacheTimeout = "60000";

              blob = "true";
              clob = "true";
              validate = "false";
              storage = "false";
              allow = "511";
              custom = {
                trustServerCertificate = "true";
                SelectMethod = "direct";
                authentication = "SqlPassword";

                DATABASENAME = cfConfig.dataSources.${project}.database;
                applicationIntent = "ReadWrite";
                sendStringParametersAsUnicode = "true";
                authenticationScheme = "NativeAuthentication";
              };

              dbdriver = "MSSQL";

              paramDelimiter = ";";
              paramLeadingDelimiter = ";";
              paramSeparator = "=";
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
                # Override username, password, host, and port with environment variables
                username = "\${DATABASE_USERNAME}";
                password = "\${DATABASE_PASSWORD}";
                host = "\${DATABASE_HOST}";
                port = "\${DATABASE_PORT}";
              }
            );
          };
        };

        # to see all avialable extensions run:
        # nix eval --impure --expr 'let flake = builtins.getFlake "github:emotions-ch/lucee-nix"; pkgs = import <nixpkgs> { overlays = [ flake.overlays.default ]; }; in builtins.attrNames pkgs.luceeExtensions'
        extensions = [
          pkgs.luceeExtensions."org.lucee.mssql"
          pkgs.luceeExtensions.image-extension
          pkgs.luceeExtensions.compress
        ];

        # supplies configuration for lucee-manager in local development (entirely optional but useful if one is running multiple instances)
        # https://github.com/emotions-ch/lucee-manager/
        luceeManagerJson = pkgs.writeText ".lucee-manager.json" "${builtins.toJSON {
          project = project;
          domain = "${project}.devlocal.emotions.ch";
          nginx.templateFile = ./nginx.conf;
        }}";

      in
      {
        devShells.default = pkgs.mkShell {
          name = "${project}-nix-dev";

          buildInputs = with pkgs; [
            nixpkgs-fmt
            statix
            deadnix

            jq
            openjdk25

            startScript
            initScript
          ];

          shellHook = ''
            echo "  nixpkgs-fmt         - Format Nix files"
            echo "  statix              - Lint Nix files"
            echo "  deadnix             - Find dead code in Nix files"
            echo "  start-lucee"
            echo ""
          '';
        };
        packages = {
          lucee = startScript;
          default = startScript;

          # Docker image for production deployment of a masa application
          dockerImage = pkgs.mkLuceeDockerImage {
            inherit
              lucee
              extensions
              project
              ;
            webapp = ./wwwroot; # folder containing your index.cfm
            isMasa = true;
            cfConfig = prodCfConfig;

            # for GHCR integration
            name = "ghcr.io/example/${project}";
            imageConfig = {
              Labels = {
                "org.opencontainers.image.source" = "https://github.com/example/${project}";
              };
            };
          };
        };
      }
    )
    // { };
}
