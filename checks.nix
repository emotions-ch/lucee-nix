{ pkgs
, src # project root, i.e. `./.` written in the *project's* flake. Cannot be

, name ? null # project name, used to name the image test
, image ? null # mkLuceeDockerImage result; omit for devshell-only projects
, formatter ? pkgs.nixfmt-tree
, imageTest ? { } # extra args merged into the mkLuceeImageTest call
, extra ? { } # project-specific additional checks
,
}:

let
  inherit (pkgs) lib;
in
{
  nix-fmt = pkgs.runCommand "check-nix-formatting" { } ''
    cd ${src}
    ${lib.getExe formatter} --ci --fail-on-change

    touch $out
  '';
}
// lib.optionalAttrs (image != null) {
  # Boots the image and asserts Lucee serves. Hermetic, so it deliberately does
  # not cover database connectivity - see ./test.nix.

  image-health = pkgs.mkLuceeImageTest (
    {
      inherit image;
      name = if name == null then "lucee-image-health" else "${name}-image-health";
    }
    // imageTest
  );
}
  // extra
