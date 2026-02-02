{  pkgs, ... }:
let
  lucee = pkgs.stdenv.mkDerivation {
    name = "lucee-7.0.1.100.jar";
    src = pkgs.fetchurl {
      url = "https://cdn.lucee.org/${lucee.name}";
      sha256 = "0s56sd4m71ryqkn6szd4xd24rhmmv5zsl3frvrs6f6s8bf8invi0";
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out
      cp $src $out/lucee.jar
    '';
  };

  serverXml = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/lucee/lucee-installer/6c16fd305c22cd2022c1f64e7ab31dca1bdb3112/lucee/tomcat9/tomcat-lucee-conf/conf/server.xml"; #server.xml from lucee7 installer
    sha256 = "0ppizzx1q2lpfl8mn3bhaf145dj38pmj0cpgax21jx68fcy98m8s";
  };

  contextXml = pkgs.fetchurl {
    url = "https://github.com/lucee/lucee-installer/raw/0d5e993ba99aa7ce4b64b1d26e73e250b9b30a3b/lucee/tomcat9/tomcat-lucee-conf/conf/context.xml"; #context.xml from lucee7 installer
    sha256 = "04ldddb8pq7y3y5yggz29ghq9i08a8jgs4v12is0hhppm9b23hir";
  };

  webXml = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/lucee/lucee-installer/a22896f9b0caef10ea19943ba6302f2499bda96c/lucee/tomcat9/tomcat-lucee-conf/conf/web.xml"; #web.xml from lucee7 installer
    sha256 = "1kxg7yymi7gyzf3pa6yn521d86zmgn9mivy2skpn3hbfaa0qar9m";
  };

  catalinaProperties = pkgs.stdenv.mkDerivation {
    # this is a derivation because we are overriding the default catalina.properties which does get modified in the service config so we need to apply the same modifications to ourt
    # https://github.com/NixOS/nixpkgs/blob/ed142ab1b3a092c4d149245d0c4126a5d7ea00b0/nixos/modules/services/web-servers/tomcat.nix#L237C1-L241C87 
    name = "catalinaProperties-service-patch";
    src = pkgs.fetchurl {
      url = "https://github.com/lucee/lucee-installer/raw/860059147b84686b2d3db681cc30f216bc17c4f7/lucee/tomcat10/conf/catalina.properties"; # catalina.properties from lucee7 installer
      sha256 = "1i9vbgg39gxzgn4zw3gbm5apfqchksvqssna1dg2jbd253xydllx";
    };

    dontUnpack = true;
    buildInputs = [ pkgs.gnused ];

    installPhase = ''
      # Create a modified catalina.properties file
      # Change all references from CATALINA_HOME to CATALINA_BASE and add support for shared libraries
      sed -e 's|''${catalina.home}|''${catalina.base}|g' \
        -e 's|shared.loader=|shared.loader=''${catalina.base}/shared/lib/*.jar|' \
        $src > $out
    '';
  };
in
{
  services.tomcat = {
    enable = true;
    package = pkgs.tomcat11;
    jdk = pkgs.openjdk25;
    commonLibs = [ "${lucee}/lucee.jar" ];

    serverXml = builtins.readFile serverXml;
    extraConfigFiles = [
      contextXml
      webXml
      catalinaProperties
    ];

    webapps = ["${pkgs.fetchFromGitHub {
      owner = "lucee";
      repo = "lucee-installer";
      rev = "da57a8ec6e2993ed873445dde2ce4ea8dc2c4bb8";
      sha256 = "sha256-KqdDwzSy1r9jiIMVRJHyLaQgsdUk75TIOI9LsSISOII=";
    }}/lucee/tomcat9/tomcat-lucee-conf"];
  };
}

