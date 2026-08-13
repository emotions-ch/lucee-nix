# Regression coverage for mkLuceeDockerImage itself. Without this the only
# signal that the image still boots comes from a downstream project's CI, which
# needs secrets and a reachable database.
{ pkgs }:

let
  # Smallest possible app that still exercises the whole image pipeline.
  # No datasource, so nothing in it wants a database.
  webapp = pkgs.runCommand "lucee-selftest-wwwroot" { } ''
    mkdir -p $out/assets $out/core/mura

    printf '<cfoutput>SELFTEST #server.lucee.version# PATH_INFO=[#cgi.path_info#] QS=[#cgi.query_string#]</cfoutput>' \
      > $out/index.cfm

    printf 'STATICFILE' > $out/assets/static.txt
    printf 'STATICSPACE' > "$out/assets/a file.txt"

    # patch(1) fails the build if the Masa patch target is missing. The leading
    # blank line is the hunk's first context line, so it has to be there.
    cat > $out/core/mura/Portcullis.cfc <<'CFC'

    	<cffunction name="removeNullChars" access="private" output="false">
    		<cfargument name="theString" type="string" required="true" />
    		<cfreturn urldecode(replace(encodeForURL(arguments.theString),"%00","","all"))>
    	</cffunction>

    </cfcomponent>
    CFC
  '';

  # Masa is the larger shape - patches, cache dirs, SES rewrite,
  # database-dependent readiness - so the image test covers that one. The plain
  # instance is covered without a VM by the `tomcat-masa-rewrite` check.
  lucee = pkgs.mkTomcatLucee {
    luceeJar = "lucee7-zero";
    isMasa = true;
  };

  image = pkgs.mkLuceeDockerImage {
    inherit lucee webapp;
    extensions = [ ];
    cfConfig = { };
    project = "lucee-selftest";
    # Fully qualified on purpose: a test VM has no search registries, so podman
    # cannot resolve a short name.
    name = "localhost/lucee-nix-selftest";
    LUCEE_JAVA_OPTS = "-Xms64m -Xmx384m";
  };

in
{
  inherit lucee image;

  image-health = pkgs.mkLuceeImageTest {
    inherit image;
    name = "lucee-nix-image-health";
    diskSize = 10240;
    extraTestScript = ''
      with subtest("ROOT context renders CFML"):
          machine.succeed(
              "curl -fsS --max-time 10 http://127.0.0.1:8888/ | grep -q SELFTEST"
          )

      with subtest("lucee state is owned by the runtime user"):
          # The warmup runs as root at build time; if its output is not
          # chowned afterwards, uid 999 cannot read its own config.
          owners = machine.succeed(
              "podman exec --user root lucee stat -c '%n %U' "
              "/opt/lucee /opt/lucee/conf /opt/lucee/work /opt/lucee/server"
          )
          print(owners)
          assert " root" not in owners, f"root-owned state:\n{owners}"

      with subtest("SES paths are rewritten onto index.cfm"):
          machine.succeed(
              "curl -fsS --max-time 10 http://127.0.0.1:8888/kontakt/ "
              "| grep -qF 'PATH_INFO=[/kontakt/]'"
          )

      with subtest("explicit index.cfm paths are not rewritten twice"):
          machine.succeed(
              "curl -fsS --max-time 10 http://127.0.0.1:8888/index.cfm/kontakt/ "
              "| grep -qF 'PATH_INFO=[/kontakt/]'"
          )

      with subtest("query strings survive the rewrite"):
          machine.succeed(
              "curl -fsS --max-time 10 'http://127.0.0.1:8888/kontakt/?a=1&b=2' "
              "| grep -qF 'QS=[a=1&b=2]'"
          )

      with subtest("existing files are served, not swallowed by index.cfm"):
          machine.succeed(
              "curl -fsS --max-time 10 http://127.0.0.1:8888/assets/static.txt "
              "| grep -q STATICFILE"
          )
          # Percent-encoded on the wire: fails if -f tests the encoded
          # %{REQUEST_URI} instead of the decoded %{REQUEST_PATH}.
          machine.succeed(
              "curl -fsS --max-time 10 'http://127.0.0.1:8888/assets/a%20file.txt' "
              "| grep -q STATICSPACE"
          )

      with subtest("the health context is not rewritten"):
          machine.succeed(
              "curl -fsS --max-time 10 http://127.0.0.1:8888/health/ | grep -q OK"
          )

      with subtest("masa patches were applied to /app"):
          machine.succeed(
              "podman exec lucee grep -q 'urlEncode(arguments.theString)' "
              "/app/core/mura/Portcullis.cfc"
          )
    '';
  };
}
