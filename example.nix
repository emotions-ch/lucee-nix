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
  imports = [
    (import ./systemd.nix { inherit lib config pkgs extensions lucee-dir; })
  ];

  services.tomcat = {
    enable = true;
    package = tomcat-lucee;
    jdk = pkgs.openjdk"${luceeUtils.jar.lucee7-zero.javaVersion}";
    purifyOnStart = true;
    port = 8888;

    serverXml = builtins.readFile "${tomcat-lucee}/conf/server.xml";

    webapps = [ luceeUtils.examplePage ];
  };
}

