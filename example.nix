{ lib, config, pkgs, ... }:
let
  lucee = pkgs.stdenv.mkDerivation {
    version = "light-7.0.1.100";
    name = "lucee-${lucee.version}";
    src = pkgs.fetchurl {
      url = "https://cdn.lucee.org/${lucee.name}.jar";
      sha256 = "1biwx0qx4r3fnpm6n88zjw3f6f02bm3hz497nvkkkm9lqw9hkg0j";
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out
      cp $src $out/lucee.jar
    '';
  };

  lucee-dockerfiles = pkgs.fetchFromGitHub {
    owner = "lucee";
    repo = "lucee-dockerfiles";
    rev = "0b34c46e8c1385d7c4014ee6c154476a9995189d";
    sha256 = "sha256-tzR30emegBC27E4XImgQrOBTYOGacaXmdvCZrvjLhsg=";
  };

  # webapp must be in directory named webapps/ROOT
  webapp = pkgs.runCommand "lucee-webapp-root" {} ''
    mkdir -p $out/webapps
    ln -s ${lucee-dockerfiles}/www $out/webapps/ROOT
  '';

  tomcat-lucee = pkgs.tomcat11.overrideAttrs (oldAttrs: {
    name = "${oldAttrs.pname}-${oldAttrs.version}-lucee-${lucee.version}";
    postFixup = (oldAttrs.postFixup or "") + ''
      cp -f ${lucee-dockerfiles}/config/tomcat/11.0/* $out/conf/

      # Replace hardcoded /var/www/ with Tomcat's webapps dir
      substituteInPlace $out/conf/server.xml \
        --replace "/var/www/" "${config.services.tomcat.baseDir}/webapps/ROOT/"

      mkdir -p $out/lucee
      ln -s ${lucee}/lucee.jar $out/lucee/lucee.jar
    '';
  });
in
{
  services.tomcat = {
    enable = true;
    package = tomcat-lucee;
    jdk = pkgs.openjdk25;
    purifyOnStart = true;

    serverXml = builtins.readFile "${tomcat-lucee}/conf/server.xml";

    webapps = [ webapp ];
  };

  systemd = {
    services = {
      tomcat = {
        after = [ "lucee-setup.service" ];
        requires = [ "lucee-setup.service" ];
        preStart = lib.mkAfter ''
          ln -sfn ${config.services.tomcat.package}/lucee ${config.services.tomcat.baseDir}
        '';
      };

      "lucee-setup" = {
        description = "Initialize /opt/lucee for Lucee";
        wantedBy = [ "multi-user.target" ];
        before = [ "tomcat.service" ];
        unitConfig.RequiresMountsFor = [ "/opt/lucee" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.coreutils}/bin/mkdir -p /opt/lucee
            ${pkgs.coreutils}/bin/chmod 0755 /opt/lucee
            ${pkgs.coreutils}/bin/chown ${config.services.tomcat.user}:${config.services.tomcat.group} /opt/lucee
          '';
          RemainAfterExit = true;
        };
      };
    };

    tmpfiles.rules = [
      # Format: d <path> <mode> <user> <group> <age or ->
      "d /opt/lucee 0755 ${config.services.tomcat.user} ${config.services.tomcat.group} -"
    ];
  };
}

