{ ... }:
{
  projectRootFile = "flake.nix";

  programs = {
    nixpkgs-fmt = {
      enable = true;
    };

    # Enable Haskell formatting with ormolu
    ormolu = {
      enable = true;
      ghcOpts = [ ];
    };
  };

  settings.formatter = {
    ormolu.excludes = [
      "tools/lucee-updater/dist-newstyle/**"
    ];

    nixpkgs-fmt.excludes = [
      "extensions/definitions.nix"
      "lucee/definitions.nix"
    ];
  };
}
