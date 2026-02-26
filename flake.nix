{
  description = "Lucee NixOS Module - Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Import our modules
          luceeUtils = import ./lucee.nix { inherit (pkgs) lib; inherit pkgs; };
          extensionUtils = import ./extensions.nix { inherit (pkgs) lib; inherit pkgs; };


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
              openjdk
            ];

            shellHook = ''
              echo "  nixpkgs-fmt         - Format Nix files"
              echo "  statix              - Lint Nix files"
              echo "  deadnix             - Find dead code in Nix files"
              echo ""
            '';
          };

          # Packages
          packages = {
            TomcatLucee = luceeUtils.mkTomcatLucee {
              luceeJar = "lucee7-zero";
            };
          };

          # Checks - automated validation
          nixosModules.default = { config, lib, pkgs, ... }: {
            imports = [
              ./lucee.nix
              ./extensions.nix
              ./systemd.nix
            ];
          };
        }) // { };
}
