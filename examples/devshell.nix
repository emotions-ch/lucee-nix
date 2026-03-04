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

  outputs = { nixpkgs, ... }@inputs:
  inputs.flake-utils.lib.eachDefaultSystem
    (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            inputs.lucee-nix.overlays.default
          ];
        };

        lucee = pkgs.mkTomcatLucee {
          baseDir = "ROOT";
        };

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
            ${pkgs.lib.concatMapStringsSep "\n            " (ext: "cp -f ${ext}/*.lex $CATALINA_BASE/lucee-server/deploy/") extensions}

            LUCEE_ENABLE_WARMUP=1 $CATALINA_BASE/bin/catalina.sh run
            echo ""
            echo "------ Warmup complete ------"
            echo ""

            DATASOURCE_SECRET=$(cat $PWD/${cfConfig.dataSources.${project}.host}.secret) $CATALINA_BASE/bin/catalina.sh run
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

        project = "my-lucee-app";
        cfConfigJSON = pkgs.writeText ".CFConfig.json" "${builtins.toJSON cfConfig}";
        cfConfig = {
          dataSources = {
            ${project} = {
              name = project;
              class = "com.microsoft.sqlserver.jdbc.SQLServerDriver";
              bundleName = "org.lucee.mssql";
              dsn = "jdbc:sqlserver://{host}:{port}";
              id = "mssql";
              username = "username";
              password = "\${DATASOURCE_SECRET}"; #database password must be placed in a file called `${host}.secret` eg. db.example.com.secret
              host = "db.example.com";
              port = "1300";
              database = "${project}-L";

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

      extensions = [ 
         pkgs.luceeExtensions."org.lucee.mssql"
         pkgs.luceeExtensions.image-extension
         pkgs.luceeExtensions.compress
      ];

      # OPTIONAL: generate metadata file for https://github.com/emotions-ch/lucee-manager
      luceeManagerJson = pkgs.writeText ".lucee-manager.json" "${builtins.toJSON {
        project = project;
        domain = "${project}.com";
      }}";

      in
      {
        # Development shell
        devShells.default = pkgs.mkShell {
          name = "lucee-nix-dev";

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
        };
      }) // { };
}
