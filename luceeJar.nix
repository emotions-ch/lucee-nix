{ lib, pkgs }:

let
  mkLuceeVersion = {
    name,
    description ? "Lucee Server Jar",
    version,
    sha256 ? lib.fakeHash
  }: pkgs.stdenv.mkDerivation {
    inherit version name description;
    src = pkgs.fetchurl {
      url = "https://cdn.lucee.org/${name}-${version}.jar";
      inherit sha256;
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out
      cp $src $out/lucee.jar
    '';
  };

  versions = {
    lucee7-zero = mkLuceeVersion {
      name = "lucee-zero";
      description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
      version = "7.0.1.100";
      sha256 = "05xzrvjan5vpd4jzq54xp0nhiiwnk6ixn6xs45f4v2wscvkapvzd";
    };
  };

in
{
  inherit mkLuceeVersion versions;
}
