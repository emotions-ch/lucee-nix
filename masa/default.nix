{ lib
, pkgs
,
}:

let
  # Pristine Masa source with our patches applied at build time. A Masa bump the
  # patches no longer fit fails here, loudly, instead of in a running instance.
  mkMasa =
    { version
    , hash ? lib.fakeHash
    , patches ? [ ]
    ,
    }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "masacms";
      inherit version patches;

      src = pkgs.fetchFromGitHub {
        owner = "MasaCMS";
        repo = "MasaCMS";
        rev = version;
        inherit hash;
      };

      dontConfigure = true;
      dontBuild = true;
      # CFML, not ELF or scripts: nothing for the fixup hooks to do.
      dontFixup = true;

      installPhase = ''
        runHook preInstall
        cp -r . $out
        runHook postInstall
      '';
    };

  webroot = import ./webroot.nix { inherit lib pkgs; };
in
{
  inherit mkMasa;
  inherit (webroot) mkMasaWebroot mkWebrootTool;

  versions = import ./definitions.nix { inherit lib mkMasa; };
}
