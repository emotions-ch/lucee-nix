{ lib, pkgs }:

let
  mkLuceeExtension =
    { name
    , description ? "Lucee Extension"
    , version
    , sha256 ? lib.fakeHash
    ,
    }:
    pkgs.stdenv.mkDerivation {
      inherit version name description;
      src = pkgs.fetchurl {
        url = "https://ext.lucee.org/${name}-${version}.lex";
        inherit sha256;
      };
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out
        cp $src $out/${name}.lex
      '';
    };

  extensionDefinitions = import ./definitions.nix { inherit mkLuceeExtension; };

in
{
  inherit mkLuceeExtension extensionDefinitions;
}
