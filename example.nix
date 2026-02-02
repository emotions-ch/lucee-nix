{ lib, config, pkgs, ... }:
let
  lucee = pkgs.stdenv.mkDerivation {
    name = "lucee-7.0.1.100";
    src = pkgs.fetchurl {
      url = "https://cdn.lucee.org/${lucee.name}.jar";
      sha256 = "0s56sd4m71ryqkn6szd4xd24rhmmv5zsl3frvrs6f6s8bf8invi0";
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

  tomcat-lucee = pkgs.tomcat11.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      cp -f ${lucee-dockerfiles}/config/tomcat/11.0/* $out/conf/
      mkdir -p $out/lucee
      cp ${lucee}/lucee.jar $out/lucee/
    '';
  });
in
{
  services.tomcat = {
    enable = true;
    package = tomcat-lucee;
    jdk = pkgs.openjdk25;

    webapps = ["${pkgs.fetchFromGitHub {
      owner = "lucee";
      repo = "lucee-installer";
      rev = "da57a8ec6e2993ed873445dde2ce4ea8dc2c4bb8";
      sha256 = "sha256-KqdDwzSy1r9jiIMVRJHyLaQgsdUk75TIOI9LsSISOII=";
    }}/lucee/tomcat9/tomcat-lucee-conf"];
  };

  systemd = {
    services = {
      tomcat = {
        after = [ "lucee-setup.service" ];
        requires = [ "lucee-setup.service" ];
        preStart = lib.mkAfter ''
          ln -sfn ${config.services.tomcat.package}/lucee ${config.services.tomcat.baseDir}/lucee
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

