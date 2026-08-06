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

          # NixOS VM test that boots an mkLuceeDockerImage result and asserts Lucee serves.
          mkLuceeImageTest = args: import ./test.nix ({ pkgs = final; } // args);

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

          # Smallest possible app that still exercises the whole image pipeline.
          # No datasource, so nothing in it wants a database.
          selfTestWebapp = pkgs.runCommand "lucee-selftest-wwwroot" { } ''
            mkdir -p $out
            printf '<cfoutput>SELFTEST #server.lucee.version#</cfoutput>' > $out/index.cfm
          '';

          selfTestImage = pkgs.mkLuceeDockerImage {
            lucee = self.packages.${system}.stable;
            extensions = [ ];
            cfConfig = { };
            project = "lucee-selftest";
            # Fully qualified on purpose: a test VM has no search registries, so
            # podman cannot resolve a short name.
            name = "localhost/lucee-nix-selftest";
            webapp = selfTestWebapp;
            isMasa = false;
            LUCEE_JAVA_OPTS = "-Xms64m -Xmx384m";
          };
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
            lucee-updater = pkgs.haskellPackages.callCabal2nix "lucee-updater" ./tools/lucee-updater { };
            update-lucee = pkgs.writeShellScriptBin "update-lucee" ''
              echo "🔄 Updating Lucee definitions with Haskell tool..."
              echo ""
              echo "y" | ${self.packages.${system}.lucee-updater}/bin/lucee-updater "$@"
              rm ./*.tmp
            '';
          };

          # `packages` may only hold flat derivations
          legacyPackages = {
            lucee-extensions = pkgs.luceeExtensions;
          };

          formatter = treefmtEval.config.build.wrapper;

          # for `nix flake check`
          checks = {
            formatting = treefmtEval.config.build.check self;
          }
          # NixOS tests need a linux guest; eachDefaultSystem also covers darwin.
          // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            # Regression coverage for mkLuceeDockerImage itself. Without this the
            # only signal that the image still boots comes from a downstream
            # project's CI, which needs secrets and a reachable database.
            image-health = pkgs.mkLuceeImageTest {
              name = "lucee-nix-image-health";
              image = selfTestImage;
              diskSize = 10240;
              extraTestScript = ''
                with subtest("ROOT context renders CFML"):
                    machine.succeed(
                        "curl -fsS --max-time 10 http://127.0.0.1:8888/ | grep -q SELFTEST"
                    )

                with subtest("lucee state is owned by the runtime user"):
                    # The warmup runs as root at build time; if its output is not
                    # chowned afterwards, uid 999 cannot read its own config.
                    owners = machine.succeed(
                        "podman exec --user root lucee stat -c '%n %U' "
                        "/opt/lucee /opt/lucee/conf /opt/lucee/work /opt/lucee/server"
                    )
                    print(owners)
                    assert " root" not in owners, f"root-owned state:\n{owners}"
              '';
            };
          };
        }
      )
    // {
      # Expose overlay at flake level
      overlays.default = luceeOverlay;
    };
}
