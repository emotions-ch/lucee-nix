# Masa-specific checks, merged into the flake's `checks`.
{ pkgs
, masaLucee # mkTomcatLucee { isMasa = true; } result
, plainLucee # mkTomcatLucee result without isMasa
,
}:

{
  tomcat-masa-rewrite = pkgs.runCommand "check-masa-rewrite" { } ''
    masa=${masaLucee}
    plain=${plainLucee}

    grep -q 'rewrite.RewriteValve' "$masa/conf/server.xml"
    grep '<Valve ' "$masa/conf/server.xml" | head -1 | grep -q 'rewrite.RewriteValve'
    test -f "$masa/conf/Catalina/127.0.0.1/rewrite.config"

    ! grep -q 'RewriteValve' "$plain/conf/server.xml"
    ! test -e "$plain/conf/Catalina"

    grep -q 'allowLinking="true"' "$masa/conf/context.xml"
    ! grep -q 'allowLinking' "$plain/conf/context.xml"

    touch $out
  '';

  masa-webroot-link =
    let
      mkFakeMasa =
        name:
        pkgs.runCommand name { } ''
          mkdir -p $out/core/appcfc $out/config $out/sites/default $out/shared
          echo masa > $out/index.cfm
          echo masa > $out/core/appcfc/settings.cfm
          echo masa > $out/config/Application.cfc
          echo masa > $out/sites/default/index.cfm
          echo masa > $out/shared/y.cfm
          printf 'same\n' > $out/README.md
        '';
      fakeMasa = mkFakeMasa "fake-masa";
      fakeMasa2 = mkFakeMasa "fake-masa-2";
      toolFor =
        masa:
        pkgs.lib.getExe
          (pkgs.mkTomcatLucee {
            luceeJar = "lucee7-zero";
            isMasa = true;
            inherit masa;
          }).webrootTool;
      tool = toolFor fakeMasa;
      tool2 = toolFor fakeMasa2;
    in
    pkgs.runCommand "check-masa-webroot-link" { } ''
      mkdir -p www/config www/sites/mysite/cache elsewhere
      echo project > www/index.cfm
      echo project > www/sites/mysite/index.cfm
      printf 'same\r\n' > www/README.md
      # a project dir that is itself a symlink and also exists in Masa
      echo project > elsewhere/x.cfm
      ln -s ../elsewhere www/shared

      # the instance shape: <base>/webapps/ROOT and <base>/lucee-server
      mkdir -p base/webapps base/lucee-server/context/cfclasses
      echo stale > base/lucee-server/context/cfclasses/junk
      root=base/webapps/ROOT

      ${tool} link www $root
      test "$(cat $root/index.cfm)" = project
      test "$(readlink $root/core/appcfc/settings.cfm)" = ${fakeMasa}/core/appcfc/settings.cfm
      test -d $root/core/appcfc && ! test -L $root/core && ! test -L $root/config
      test "$(readlink $root/sites/mysite)" = "$PWD/www/sites/mysite"
      test -f $root/shared/x.cfm && test -f $root/shared/y.cfm

      # first link against this Masa clears a class cache compiled for another one
      ! test -e base/lucee-server/context/cfclasses/junk
      test "$(cat base/webapps/.lucee-webroot-masa)" = ${fakeMasa}

      # runtime writes: into a wwwroot-only dir directly, into a merged dir via adoption
      echo upload > $root/sites/mysite/cache/file
      test -f www/sites/mysite/cache/file
      echo installed > $root/config/settings.ini.cfm
      mkdir -p $root/WEB-INF && echo lucee > $root/WEB-INF/x
      # Lucee's fileCopy swaps a link for a regular file: identical content is
      # dropped, changed content wins over wwwroot (overlay copy-up semantics)
      cp --remove-destination ${fakeMasa}/config/Application.cfc $root/config/Application.cfc
      rm $root/index.cfm && echo rewritten > $root/index.cfm
      mkdir -p base/lucee-server/context/cfclasses && echo compiled > base/lucee-server/context/cfclasses/keep
      ${tool} link www $root
      test "$(cat www/config/settings.ini.cfm)" = installed
      test -L $root/config/settings.ini.cfm
      ! test -e www/WEB-INF
      ! test -e www/config/Application.cfc
      test "$(readlink $root/config/Application.cfc)" = ${fakeMasa}/config/Application.cfc
      test "$(cat www/index.cfm)" = rewritten
      ! test -e www/index.cfm.runtime
      # same Masa again: the class cache survives
      test -f base/lucee-server/context/cfclasses/keep

      # a Masa bump clears it
      ${tool2} link www $root
      ! test -e base/lucee-server/context/cfclasses/keep
      test "$(readlink $root/index.cfm)" = "$PWD/www/index.cfm"

      # the old layout with a trailing slash must not empty wwwroot
      mkdir -p old/webapps && ln -s "$PWD/www" old/webapps/ROOT
      ${tool} link www old/webapps/ROOT/
      test "$(cat www/index.cfm)" = rewritten
      ! test -e www/index.cfm.runtime
      ! test -L old/webapps/ROOT && test -L old/webapps/ROOT/index.cfm
      ! ${tool} link www www 2>/dev/null
      ! ${tool} link www www/sub 2>/dev/null
      test -f www/index.cfm

      # purge: a dry run lists vendored Masa files, --apply deletes them
      ${tool} purge www > purge.log
      grep -qx README.md purge.log
      test -f www/README.md
      ${tool} purge www --apply
      ! test -e www/README.md
      test -f www/index.cfm

      touch $out
    '';
}
