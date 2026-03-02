{
  description = "Lucee NixOS Module - Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Define overlay outside system scope to avoid circular dependency
      luceeOverlay = final: prev:
        let
          luceeUtils = import ./lucee.nix { inherit (final) lib; pkgs = final; };
          extensionUtils = import ./extensions.nix { inherit (final) lib; pkgs = final; };

          mkTomcatLucee = pkgs: {
            baseDir ? "webapps/ROOT/",
            port ? 8888,
            luceeJar ? "lucee7-zero",
            tomcatPackage ? luceeUtils.jar.lucee7-zero.tomcatPackage
          }: luceeUtils.mkTomcatLucee {
            inherit luceeJar port baseDir tomcatPackage;
          };
        in {
          # Here we pass `final` (the final pkgs set) to our generator
          mkTomcatLucee = mkTomcatLucee final;
          mkLuceeExtension = extensionUtils.mkLuceeExtension;
          luceeExtensions = extensionUtils.extensionDefinitions;
        };
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ luceeOverlay ];
          };
        in {
          # Development shell
          devShells.default = pkgs.mkShell {
            name = "lucee-nix-dev";

            buildInputs = with pkgs; [
              nixpkgs-fmt
              statix
              deadnix

              jq
              openjdk
            ];

            shellHook = ''
              echo "  nixpkgs-fmt         - Format Nix files"
              echo "  statix              - Lint Nix files"
              echo "  deadnix             - Find dead code in Nix files"
              echo ""
            '';
          };

          overlays.default = luceeOverlay;

          # Packages
          packages = {
            default = pkgs.mkTomcatLucee { };
          };

          # Checks - automated validation
          nixosModules.default = { config, lib, pkgs, ... }: {
            imports = [
              ./lucee.nix
              ./extensions.nix
              ./systemd.nix
            ];
          };
        }) // {
          # Expose overlay at flake level
          overlays.default = luceeOverlay;
        };
}
