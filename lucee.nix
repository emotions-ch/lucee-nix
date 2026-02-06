{ lib, pkgs }:

let
  lucee-dockerfiles = pkgs.fetchFromGitHub {
    owner = "lucee";
    repo = "lucee-dockerfiles";
    rev = "0b34c46e8c1385d7c4014ee6c154476a9995189d";
    sha256 = "sha256-tzR30emegBC27E4XImgQrOBTYOGacaXmdvCZrvjLhsg=";
  };

  mkLuceeVersion = {
    name,
    description ? "Lucee Server Jar",
    version,
    sha256 ? lib.fakeHash,
    tomcatPackage ? pkgs.tomcat11,
    javaVersion ? 21
  }: pkgs.stdenv.mkDerivation {
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

  # Helper functions to create Lucee versions with specific Tomcat versions
  mkLuceeWithTomcat9 = args: mkLuceeVersion (args // { tomcatPackage = pkgs.tomcat9; });
  mkLuceeWithTomcat10 = args: mkLuceeVersion (args // { tomcatPackage = pkgs.tomcat10; });
  mkLuceeWithTomcat11 = args: mkLuceeVersion (args // { tomcatPackage = pkgs.tomcat11; });

  jar = {
    lucee7-zero = mkLuceeVersion {
      name = "lucee-zero";
      description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
      version = "7.0.1.100";
      sha256 = "05xzrvjan5vpd4jzq54xp0nhiiwnk6ixn6xs45f4v2wscvkapvzd";
      javaVersion = 25;
    };
  };

  # webapp must be in directory named webapps/ROOT
  examplePage = pkgs.runCommand "lucee-webapp-root" {} ''
    mkdir -p $out/webapps
    ln -s ${lucee-dockerfiles}/www $out/webapps/ROOT
  '';

  mkTomcatLucee = { config, luceeJar, tomcatPackage ? luceeJar.tomcatPackage }: 
    let
      # Extract major version from Tomcat package version (e.g., "11.0.2" -> "11.0")
      tomcatMajorVersion = lib.concatStringsSep "." (lib.take 2 (lib.splitString "." tomcatPackage.version));
    in
    tomcatPackage.overrideAttrs (oldAttrs: {
      name = "${oldAttrs.pname}-${oldAttrs.version}-lucee-${luceeJar.version}";
      postFixup = (oldAttrs.postFixup or "") + ''
        cp -f ${lucee-dockerfiles}/config/tomcat/${tomcatMajorVersion}/* $out/conf/

      # Replace hardcoded /var/www/ with Tomcat's webapps dir
      substituteInPlace $out/conf/server.xml \
        --replace '/var/www/' '${config.services.tomcat.baseDir}/webapps/ROOT/' \
        --replace 'port="8888"' 'port="${toString config.services.tomcat.port}"'

      mkdir -p $out/lucee
      ln -s ${luceeJar}/lucee.jar $out/lucee/lucee.jar
    '';
  });

in
{
  inherit mkLuceeVersion jar examplePage mkTomcatLucee lucee-dockerfiles;
  inherit mkLuceeWithTomcat9 mkLuceeWithTomcat10 mkLuceeWithTomcat11;
}
