{
  description = "Lucee NixOS Module - Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lucee-dockerfiles = {
      url = "github:lucee/lucee-dockerfiles";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , treefmt-nix
    , lucee-dockerfiles
    ,
    }:
    let
      # Define overlay outside system scope to avoid circular dependency
      luceeOverlay =
        final: prev:
        let
          luceeUtils = import ./lucee {
            inherit (final) lib;
            pkgs = final;
            inherit lucee-dockerfiles;
          };
          extensionUtils = import ./extensions {
            inherit (final) lib;
            pkgs = final;
          };

          mkTomcatLucee =
            pkgs:
            { luceeJar
            , baseDir ? "ROOT"
            , port ? 8888
            , tomcatPackage ? luceeUtils.jar.lucee7-zero.tomcatPackage
            , isMasa ? false
            ,
            }:
            luceeUtils.mkTomcatLucee {
              inherit
                luceeJar
                port
                baseDir
                tomcatPackage
                isMasa
                ;
            };

          mkLuceeDockerImage =
            { lucee
            , extensions ? [ ]
            , cfConfig
            , project
            , webapp
            , LUCEE_JAVA_OPTS ? "-Xms64m -Xmx512m"
            , javaPackage ? final.openjdk25_headless
            , tag ? "latest"
            , name ? project
            , imageConfig ? { }
            , # pkgs.dockerTools.streamLayeredImage.config for stuff like labels
            }:
            import ./docker {
              pkgs = final;
              inherit
                lucee
                extensions
                cfConfig
                project
                webapp
                LUCEE_JAVA_OPTS
                javaPackage
                tag
                name
                imageConfig
                ;
            };

          # NixOS VM test that boots an mkLuceeDockerImage result and asserts Lucee serves.
          mkLuceeImageTest = args: import ./docker/test.nix ({ pkgs = final; } // args);

          # The standard `checks` output for a project. See ./checks.nix.
          mkLuceeChecks = args: import ./checks.nix ({ pkgs = final; } // args);
        in
        {
          # Here we pass `final` (the final pkgs set) to our generator
          mkTomcatLucee = mkTomcatLucee final;
          mkLuceeExtension = extensionUtils.mkLuceeExtension;
          luceeExtensions = extensionUtils.extensionDefinitions;
          mkLuceeDockerImage = mkLuceeDockerImage;
          mkLuceeImageTest = mkLuceeImageTest;
          mkLuceeChecks = mkLuceeChecks;
        };
    in
    flake-utils.lib.eachDefaultSystem
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ luceeOverlay ];
          };

          # Eval the treefmt modules from ./treefmt.nix
          treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

          selfTest = import ./docker/selftest.nix { inherit pkgs; };
        in
        {
          # Development shell
          devShells.default = pkgs.mkShell {
            name = "lucee-nix-dev";

            buildInputs = with pkgs; [
              jq
              openjdk
              ghc
            ];

            shellHook = ''
              echo "  nix fmt             - Format Nix and Haskell files"
              echo "  nix run .#lucee-updater - Update Lucee definitions"
              echo ""
            '';
          };

          # Packages
          packages = {
            default = self.packages.${system}.stable;

            stable = pkgs.mkTomcatLucee { luceeJar = "lucee7-zero"; };

            # Lucee definitions updater
            #lucee-updater = pkgs.haskellPackages.callCabal2nix "lucee-updater" ./tools/lucee-updater { };
            #update-lucee = pkgs.writeShellScriptBin "update-lucee" ''
            #  echo "🔄 Updating Lucee definitions with Haskell tool..."
            #  echo ""
            #  echo "y" | ${self.packages.${system}.lucee-updater}/bin/lucee-updater "$@"
            #  rm ./*.tmp
            #'';
          };

          # `packages` may only hold flat derivations
          legacyPackages = {
            lucee-extensions = pkgs.luceeExtensions;
          };

          formatter = treefmtEval.config.build.wrapper;

          # for `nix flake check`
          checks = {
            formatting = treefmtEval.config.build.check self;

            tomcat-masa-rewrite = pkgs.runCommand "check-masa-rewrite" { } ''
              masa=${selfTest.lucee}
              plain=${self.packages.${system}.stable}

              grep -q 'rewrite.RewriteValve' "$masa/conf/server.xml"
              grep '<Valve ' "$masa/conf/server.xml" | head -1 | grep -q 'rewrite.RewriteValve'
              test -f "$masa/conf/Catalina/127.0.0.1/rewrite.config"

              ! grep -q 'RewriteValve' "$plain/conf/server.xml"
              ! test -e "$plain/conf/Catalina"

              touch $out
            '';
          }
          # NixOS tests need a linux guest; eachDefaultSystem also covers darwin.
          // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            inherit (selfTest) image-health;
          };
        }
      )
    // {
      # Expose overlay at flake level
      overlays.default = luceeOverlay;
    };
}
