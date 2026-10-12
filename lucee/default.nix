{ lib
, pkgs
, lucee-dockerfiles
,
}:

let
  mkLuceeVersion =
    { name
    , description ? "Lucee Server Jar"
    , version
    , sha256 ? lib.fakeHash
    , tomcatPackage ? pkgs.tomcat11
    , javaVersion ? 21
    ,
    }:
    pkgs.stdenv.mkDerivation {
      inherit version name description;
      passthru = {
        inherit tomcatPackage javaVersion;
      };
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

  rewrite = import ./rewrite.nix { };

  inherit (import ../masa/webroot.nix { inherit lib pkgs; }) mkWebrootTool;

  jar =
    import ./definitions.nix { inherit mkLuceeVersion; }
    // (import ./source.nix { inherit lib pkgs; }).jars;

  # webapp must be in directory named webapps/ROOT
  examplePage = pkgs.runCommand "lucee-webapp-root" { } ''
    mkdir -p $out/webapps
    ln -s ${lucee-dockerfiles}/www $out/webapps/ROOT
  '';

  mkTomcatLucee =
    { baseDir ? "webapps/ROOT/"
    , port ? 8888
    , luceeJar
    , tomcatPackage ? jar.${luceeJar}.tomcatPackage
    , isMasa ? false
    , masa ? null
    ,
    }:
    let
      masa' = if isMasa then masa else null;

      # Extract major version from Tomcat package version (e.g., "11.0.2" -> "11.0")
      tomcatMajorVersion = lib.concatStringsSep "." (
        lib.take 2 (lib.splitString "." tomcatPackage.version)
      );
    in
    tomcatPackage.overrideAttrs (oldAttrs: {
      name = "${oldAttrs.pname}-${oldAttrs.version}-${jar.${luceeJar}.name}-${jar.${luceeJar}.version}";

      # mkLuceeDockerImage reads this instead of taking its own isMasa argument -
      # the instance knows what it is, projects should not have to say it twice.
      passthru = (oldAttrs.passthru or { }) // {
        inherit isMasa;
        masa = masa';
        webrootTool = mkWebrootTool { masa = masa'; };
      };

      postFixup = (oldAttrs.postFixup or "") + ''
          cp -f ${lucee-dockerfiles}/config/tomcat/${tomcatMajorVersion}/* $out/conf/

        # Replace hardcoded /var/www/ with Tomcat's webapps dir
        substituteInPlace $out/conf/server.xml \
          --replace '/var/www/' '${baseDir}' \
          --replace 'port="8888"' 'port="${toString port}"'

        ${lib.optionalString isMasa (rewrite.installMasaRewrite { conf = "$out/conf"; })}
        ${lib.optionalString (masa' != null) ''
          # The dev webroot links Masa's static files (admin css/js, ...) into the
          # store; without this Tomcat's DefaultServlet answers 404 for them.
          test "$(grep -c '<Context>' $out/conf/context.xml)" = 1
          sed -i 's|<Context>|<Context>\n    <Resources allowLinking="true" />|' $out/conf/context.xml
        ''}

        mkdir -p $out/lucee
        ln -s ${jar.${luceeJar}}/lucee.jar $out/lucee/lucee.jar
      '';
    });

in
{
  inherit
    mkLuceeVersion
    jar
    examplePage
    mkTomcatLucee
    lucee-dockerfiles
    ;
}
