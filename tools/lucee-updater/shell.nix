{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    haskell.compiler.ghc948
    cabal-install
    haskellPackages.haskell-language-server
    lix
    curl
    # For development
    haskellPackages.ghcid
  ];
  
  shellHook = ''
    echo "Lucee Updater Development Environment"
    echo "Commands:"
    echo "  cabal build         - Build the project"
    echo "  cabal repl          - Start GHCI"
    echo "  cabal run           - Run the updater"
    echo "  ghcid               - Live reload development"
    echo ""
  '';
}
