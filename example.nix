{ lib, config, pkgs, ... }:
let
  extensionUtils = import ./extensions.nix { inherit lib pkgs; };
  luceeJarUtils = import ./lucee.nix { inherit lib pkgs; };
  lucee-dir = "/opt/lucee";

  lucee = luceeJarUtils.versions.lucee7-zero; #admin & docs can be added as extensions if needed

  lucee-dockerfiles = pkgs.fetchFromGitHub {
    owner = "lucee";
    repo = "lucee-dockerfiles";
    rev = "0b34c46e8c1385d7c4014ee6c154476a9995189d";
    sha256 = "sha256-tzR30emegBC27E4XImgQrOBTYOGacaXmdvCZrvjLhsg=";
  };

  extensions = {
    inherit (extensionUtils.extensionDefinitions)
      cfspreadsheet
      administrator-extension;
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
        --replace '/var/www/' '${config.services.tomcat.baseDir}/webapps/ROOT/' \
        --replace 'port="8888"' 'port="${toString config.services.tomcat.port}"'

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
    port = 8888;

    serverXml = builtins.readFile "${tomcat-lucee}/conf/server.xml";

    webapps = [ webapp ];
  };

  systemd = {
    services = {
      tomcat = {
        after = [ "lucee-setup.service" "lucee-extension-deploy.service" ];
        requires = [ "lucee-setup.service" "lucee-extension-deploy.service" ];
        preStart = lib.mkAfter ''
          ln -sfn ${config.services.tomcat.package}/lucee ${config.services.tomcat.baseDir}
        '';
      };

      "lucee-setup" = {
        description = "Initialize ${lucee-dir} for Lucee";
        wantedBy = [ "multi-user.target" ];
        before = [ "tomcat.service" ];
        unitConfig.RequiresMountsFor = [ "${lucee-dir}" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.coreutils}/bin/mkdir -p ${lucee-dir}
            ${pkgs.coreutils}/bin/chmod 0755 ${lucee-dir}
            ${pkgs.coreutils}/bin/chown -R ${config.services.tomcat.user}:${config.services.tomcat.group} ${lucee-dir}
          '';
          RemainAfterExit = true;
        };
      };

      "lucee-extension-deploy" = {
        description = "Deploy Lucee extensions dynamically";
        wantedBy = [ "multi-user.target" ];
        after = [ "lucee-setup.service" ];
        before = [ "tomcat.service" ];
        unitConfig.RequiresMountsFor = [ "${lucee-dir}" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${extensionUtils.mkExtensionDeployScript extensions} ${lucee-dir}/server/lucee-server/deploy ${config.services.tomcat.user} ${config.services.tomcat.group}
          '';
          RemainAfterExit = true;
          # User = "root";  # Need root to change ownership
        };
      };
    };

    tmpfiles.rules = [
      # Format: d <path> <mode> <user> <group> <age or ->
      "d ${lucee-dir} 0755 ${config.services.tomcat.user} ${config.services.tomcat.group} -"
      "d ${lucee-dir}/deploy 0755 ${config.services.tomcat.user} ${config.services.tomcat.group} -"
    ];
  };
}

