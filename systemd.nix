{ lib, config, pkgs, lucee-dir, cfConfig ? {}, extensions ? {}, ... }:
let
  extensionUtils = import ./extensions.nix { inherit lib pkgs; };
  cfConfigJSON = pkgs.writeText ".CFConfig.json" "${builtins.toJSON cfConfig}";
in
{
  systemd = {
    services = {
      tomcat = {
        after = [ "lucee-setup.service" ];
        requires = [ "lucee-setup.service" ];
        preStart = lib.mkAfter ''
          cp -f ${cfConfigJSON} ${lucee-dir}/server/lucee-server/deploy/.CFConfig.json
          cp -f ${cfConfigJSON} ${lucee-dir}/.CFConfig.json
          # extensions
          ${lib.optionalString (extensions != {}) "${extensionUtils.mkExtensionDeployScript extensions} ${lucee-dir}/server/lucee-server/deploy ${config.services.tomcat.user} ${config.services.tomcat.group}"}

          ln -sfn ${config.services.tomcat.package}/lucee ${config.services.tomcat.baseDir}
        '';

        postStop = lib.mkAfter (if config.services.tomcat.purifyOnStart then ''
            ${pkgs.coreutils}/bin/rm -rf ${lucee-dir}/*
            ${pkgs.coreutils}/bin/find ${lucee-dir} -mindepth 1 -delete 2>/dev/null || true

            ${pkgs.coreutils}/bin/mkdir -p ${lucee-dir}/server/lucee-server/deploy
            ${pkgs.coreutils}/bin/chmod 0755 ${lucee-dir}
            ${pkgs.coreutils}/bin/chown -R ${config.services.tomcat.user}:${config.services.tomcat.group} ${lucee-dir}
        '' else "");
      };

      "lucee-setup" = {
        description = "Initialize ${lucee-dir} for Lucee";
        wantedBy = [ "multi-user.target" ];
        before = [ "tomcat.service" ];
        unitConfig.RequiresMountsFor = [ "${lucee-dir}" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.coreutils}/bin/mkdir -p ${lucee-dir}/server/lucee-server/deploy/
            ${pkgs.coreutils}/bin/chmod 0755 ${lucee-dir}
            ${pkgs.coreutils}/bin/chown -R ${config.services.tomcat.user}:${config.services.tomcat.group} ${lucee-dir}
          '';
          RemainAfterExit = true;
        };
      };
    };

    tmpfiles.rules = [
      # Format: d <path> <mode> <user> <group> <age or ->
      "d ${lucee-dir} 0755 ${config.services.tomcat.user} ${config.services.tomcat.group} -"
      "d ${lucee-dir}/server/lucee-server/deploy 0755 ${config.services.tomcat.user} ${config.services.tomcat.group} -"
    ];
  };
}
