{ lib, config, pkgs, ... }:
let
  extensionUtils = import ./extensions.nix { inherit lib pkgs; };
  luceeUtils = import ./lucee.nix { inherit lib pkgs; };
  lucee-dir = "/opt/lucee";

  extensions = {
    inherit (extensionUtils.extensionDefinitions)
      cfspreadsheet
      administrator-extension;
  };

  tomcat-lucee = luceeUtils.mkTomcatLucee { 
    inherit config; 
    luceeJar = luceeUtils.jar.lucee7-zero; 
  };
in
{
  services.tomcat = {
    enable = true;
    package = tomcat-lucee;
    jdk = pkgs.openjdk25;
    purifyOnStart = true;
    port = 8888;

    serverXml = builtins.readFile "${tomcat-lucee}/conf/server.xml";

    webapps = [ luceeUtils.examplePage ];
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

