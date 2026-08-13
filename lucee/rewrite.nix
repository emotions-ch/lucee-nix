{}:

let
  rewriteConfig = ./masa-rewrite.config;
in
{
  inherit rewriteConfig;

  # Shell snippet that wires Tomcat's RewriteValve into a Tomcat conf directory.
  # server.xml is copied verbatim from the lucee-dockerfiles flake input, so the
  # edit is a sed plus assertions: a restructure upstream has to stop the build
  # rather than silently yield an instance that 404s every SES URL.
  installMasaRewrite =
    { conf }:
    ''
      serverXml="${conf}/server.xml"
      test -f "$serverXml"

      hosts=$(grep -c '<Host ' "$serverXml")
      test "$hosts" = 1 || {
        echo "masa-rewrite: expected exactly one <Host> in $serverXml, found $hosts" >&2
        exit 1
      }
      grep '<Valve ' "$serverXml" | head -1 | grep -q 'RemoteIpValve' || {
        echo "masa-rewrite: RemoteIpValve is no longer the first <Valve> in $serverXml - re-anchor the injection" >&2
        exit 1
      }

      # First valve on purpose: on a rewrite Tomcat re-invokes from the head of
      # the pipeline, so every valve ahead of this one would run - and log - twice.
      sed -i 's|<Valve className="org.apache.catalina.valves.RemoteIpValve"|<Valve className="org.apache.catalina.valves.rewrite.RewriteValve" />\n        &|' "$serverXml"

      grep '<Valve ' "$serverXml" | head -1 | grep -q 'rewrite.RewriteValve' || {
        echo "masa-rewrite: injection did not take in $serverXml" >&2
        exit 1
      }

      # The valve resolves its rules through Container.getConfigPath(), i.e.
      # conf/<Engine name>/<Host name>/rewrite.config. A file anywhere else is
      # not an error - the valve logs "No configuration resource found" at INFO
      # and passes everything through, which is the bug this is fixing. So read
      # both names off server.xml instead of hardcoding them. sort -u collapses
      # the commented-out example <Engine> upstream ships (same name) and turns
      # any future divergence into a build failure.
      tomcatEngine=$(sed -n 's|.*<Engine [^>]*name="\([^"]*\)".*|\1|p' "$serverXml" | sort -u)
      tomcatHost=$(sed -n 's|.*<Host [^>]*name="\([^"]*\)".*|\1|p' "$serverXml" | sort -u)
      # Rejects both the empty and the multi-value (newline-joined) case.
      for derived in "$tomcatEngine" "$tomcatHost"; do
        case "$derived" in
          "" | *[!A-Za-z0-9._-]*)
            echo "masa-rewrite: no unique Engine/Host name in $serverXml (engine='$tomcatEngine' host='$tomcatHost')" >&2
            exit 1
            ;;
        esac
      done

      install -D -m 0644 ${rewriteConfig} "${conf}/$tomcatEngine/$tomcatHost/rewrite.config"
      echo "masa-rewrite: installed conf/$tomcatEngine/$tomcatHost/rewrite.config"
    '';
}
