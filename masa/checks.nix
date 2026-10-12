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
      fakeMasa = pkgs.runCommand "fake-masa" { } ''
        mkdir -p $out/core/appcfc $out/config $out/sites/default
        echo masa > $out/index.cfm
        echo masa > $out/core/appcfc/settings.cfm
        echo masa > $out/config/Application.cfc
        echo masa > $out/sites/default/index.cfm
        printf 'same\n' > $out/README.md
      '';
      tool = pkgs.lib.getExe (pkgs.mkTomcatLucee {
        luceeJar = "lucee7-zero";
        isMasa = true;
        masa = fakeMasa;
      }).webrootTool;
    in
    pkgs.runCommand "check-masa-webroot-link" { } ''
      mkdir -p www/config www/sites/mysite/cache
      echo project > www/index.cfm
      echo project > www/sites/mysite/index.cfm
      printf 'same\r\n' > www/README.md

      ${tool} link www root
      test "$(cat root/index.cfm)" = project
      test "$(readlink root/core/appcfc/settings.cfm)" = ${fakeMasa}/core/appcfc/settings.cfm
      test -d root/core/appcfc && ! test -L root/core && ! test -L root/config
      test "$(readlink root/sites/mysite)" = "$PWD/www/sites/mysite"

      # runtime writes: into a wwwroot-only dir directly, into a merged dir via adoption
      echo upload > root/sites/mysite/cache/file
      test -f www/sites/mysite/cache/file
      echo installed > root/config/settings.ini.cfm
      mkdir -p root/WEB-INF && echo lucee > root/WEB-INF/x
      ${tool} link www root
      test "$(cat www/config/settings.ini.cfm)" = installed
      test -L root/config/settings.ini.cfm
      ! test -e www/WEB-INF

      ${tool} prune www | grep -qx README.md
      test -f www/README.md
      ${tool} prune www --apply
      ! test -e www/README.md
      test -f www/index.cfm

      touch $out
    '';
}
