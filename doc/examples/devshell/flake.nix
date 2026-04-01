{
  description = "My Lucee Project - Development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    lucee-nix = {
      url = "github:emotions-ch/lucee-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      lucee-nix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ lucee-nix.overlays.default ];
        };

        # Create Lucee server instance
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

        # Project configuration
        project = "myproject";

        # Development database configuration
        cfConfigJSON = pkgs.writeText ".CFConfig.json" "${builtins.toJSON cfConfig}";
        cfConfig = {
          dataSources.${project} = {
            name = project;
            class = "org.postgresql.Driver";
            bundleName = "org.postgresql.jdbc";
            dsn = "jdbc:postgresql://{host}:{port}/{database}";
            username = "devuser";
            password = "\${DATASOURCE_SECRET}";
            host = "localhost";
            database = project;
            port = "5432";
            # ... additional configuration
          };
        };

        # extensions requiured by your application
        extensions = with pkgs.luceeExtensions; [
          "org.postgresql.jdbc"
          image-extension
          administrator-extension
        ];

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Runtime
            openjdk25

            # Project scripts
            startScript
            initScript
          ];
        };

        packages.default = lucee;
      }
    );
}
