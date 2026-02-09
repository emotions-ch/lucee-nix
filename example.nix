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

  # gets converted to json for CFConfig
  cfConfig = {
    dataSources = {
      myds = {
        host = "localhost";
        username = "MYDS_USERNAME";
        password = "MYDS_PASSWORD";
        url = "{system:myds.url}";
      };
    };
  };
in
{
  imports = [
    (import ./systemd.nix { inherit lib config pkgs extensions cfConfig lucee-dir; })
  ];

  services.tomcat = {
    enable = true;
    package = tomcat-lucee;
    jdk = pkgs."openjdk${luceeUtils.jar.lucee7-zero.javaVersion}";
    purifyOnStart = true;
    port = 8888;

    serverXml = builtins.readFile "${tomcat-lucee}/conf/server.xml";

    webapps = [ luceeUtils.examplePage ];
  };
}

