{ pkgs ? import <nixpkgs> { } }:

pkgs.haskellPackages.callCabal2nix "lucee-updater" ./. { }
