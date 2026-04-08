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
            ,
            }:
            luceeUtils.mkTomcatLucee {
              inherit
                luceeJar
                port
                baseDir
                tomcatPackage
                ;
            };

          mkLuceeDockerImage =
            { lucee
            , extensions ? [ ]
            , cfConfig
            , project
            , webapp
            , isMasa ? false
            , LUCEE_JAVA_OPTS ? "-Xms64m -Xmx512m"
            , javaPackage ? final.openjdk25
            , tag ? "latest"
            , name ? project
            , imageConfig ? { }
            , # pkgs.dockerTools.buildImage.config for stuff like labels
            }:
            import ./docker.nix {
              pkgs = final;
              inherit
                lucee
                extensions
                cfConfig
                project
                webapp
                isMasa
                LUCEE_JAVA_OPTS
                javaPackage
                tag
                name
                imageConfig
                ;
            };
        in
        {
          # Here we pass `final` (the final pkgs set) to our generator
          mkTomcatLucee = mkTomcatLucee final;
          mkLuceeExtension = extensionUtils.mkLuceeExtension;
          luceeExtensions = extensionUtils.extensionDefinitions;
          mkLuceeDockerImage = mkLuceeDockerImage;
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
        in
        {
          # Development shell
          devShells.default = pkgs.mkShell {
            name = "lucee-nix-dev";

            buildInputs = with pkgs; [
              jq
              openjdk
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
            rc = pkgs.mkTomcatLucee { luceeJar = "lucee7_0-RC-zero"; };
            beta = pkgs.mkTomcatLucee { luceeJar = "lucee7_1-BETA-zero"; };

            lucee-extensions = pkgs.luceeExtensions;

            # Lucee definitions updater
            lucee-updater = pkgs.haskellPackages.callCabal2nix "lucee-updater" ./tools/lucee-updater { };
            update-lucee = pkgs.writeShellScriptBin "update-lucee" ''
              echo "🔄 Updating Lucee definitions with Haskell tool..."
              echo ""
              echo "y" | ${self.packages.${system}.lucee-updater}/bin/lucee-updater "$@"
              rm ./*.tmp
            '';
          };

          formatter = treefmtEval.config.build.wrapper;

          # for `nix flake check`
          checks = {
            formatting = treefmtEval.config.build.check self;
          };
        }
      )
    // {
      # Expose overlay at flake level
      overlays.default = luceeOverlay;
    };
}
