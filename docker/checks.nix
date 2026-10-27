# Image script checks that need no VM, merged into the flake's `checks`.
{ pkgs
, masaImage # mkLuceeDockerImage result built on an isMasa lucee
,
}:

{
  container-init-env = pkgs.runCommand "check-container-init-env" { } ''
    init=${masaImage.containerInitScript}/bin/container-init.sh
    export DATABASE_HOST=db DATABASE_PORT=1433 DATABASE_USERNAME=u

    rc=0
    $init > out.log || rc=$?
    test $rc = 1
    grep -q 'ERROR: Required environment variable DATABASE_PASSWORD is not set' out.log

    rc=0
    DATABASE_PASSWORD= $init > out.log || rc=$?
    test $rc = 1
    grep -q 'DATABASE_PASSWORD is not set' out.log

    touch $out
  '';
}
