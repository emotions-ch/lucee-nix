{ lib, pkgs }:

let
  mkLuceeExtension =
    { name
    , description ? "Lucee Extension"
    , version
    , sha256 ? lib.fakeHash
    }: pkgs.stdenv.mkDerivation {
      inherit version name description;
      src = pkgs.fetchurl {
        url = "https://ext.lucee.org/${name}-${version}.lex";
        inherit sha256;
      };
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out
        cp $src $out/${name}.lex
      '';
    };

  extensionDefinitions = {
    cfspreadsheet = mkLuceeExtension {
      name = "cfspreadsheet";
      description = "A spreadsheet extension for Lucee 5";
      version = "3.0.4";
      sha256 = "1cccdqa15cafi1q4xnfmq69bq7saxl84jiwjb41mjhpmji0dsnz9";
    };

    image-extension = mkLuceeExtension {
      name = "image-extension";
      description = "Lucee Image Extension provides essential image manipulation tags and functions (cfimage, imageCrop, imageNew, etc.) for Lucee 7+ running on Jakarta EE containers. This version requires Lucee 7 and is compatible with Tomcat 10+. For Lucee 6 installations, please use Image Extension 2.x instead.";
      version = "3.0.0.6";
      sha256 = "1ddi5d96iinqfzrb8f17hp0ddckas7yx2qvjqkr9pw7wh4pn0cjv";
    };

    administrator-extension = mkLuceeExtension {
      name = "administrator-extension";
      description = "Core Extension to integrate the Lucee Administrator into Lucee.";
      version = "1.0.0.6";
      sha256 = "0181pq87max0nzc3y01agxvrapmzp7nwb4mwghz9hn6nr7idqdlg";
    };

    documentation-extension = mkLuceeExtension {
      name = "documentation-extension";
      description = "Core Extension to integrate the Lucee Documentation into Lucee.";
      version = "1.0.0.5";
      sha256 = "1m69h1x4vvnsqwkrjagnizyj5cmvycg6sf1xjvqvajzngn16dw9h";
    };

    "org.postgresql.jdbc" = mkLuceeExtension {
      name = "org.postgresql.jdbc";
      description = "JDBC Driver for the PostgreSQL Database.";
      version = "42.7.7";
      sha256 = "0yd0n2ngwqf536knslpmhi3pixqnxfm0rk3jxy8abvihq9mdri4l";
    };

    s3-extension = mkLuceeExtension {
      name = "s3-extension";
      description = "Core Extension to integrate Amazon Simple Storage Service (S3) Resource into Lucee.";
      version = "2.0.3.0";
      sha256 = "1mzjss4n8f49h7cwfwhpr9v2cpcm7sa0z6gdfcpg22120bgcli6n";
    };

    "org.lucee.mssql" = mkLuceeExtension {
      name = "org.lucee.mssql";
      description = "JDBC Driver from Microsoft for SQL Server, SQL Server is a relational database management system developed by Microsoft.";
      version = "13.2.1";
      sha256 = "0wh7q4yra7i3rqxb42pcvkad219m6z7f6dsd2gqrmh93q0d8nwqf";
    };
  };

in
{
  inherit mkLuceeExtension extensionDefinitions;

  # Function to generate deployment script for extensions
  mkExtensionDeployScript = extensions: pkgs.writeScript "deploy-extensions.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    DEPLOY_DIR="$1"
    TOMCAT_USER="$2"
    TOMCAT_GROUP="$3"

    # Deploy each extension dynamically
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: ext: ''
      echo "Deploying extension: ${name}"
      if [ -f "${ext}/${name}.lex" ]; then
        ${pkgs.coreutils}/bin/cp "${ext}/${name}.lex" "$DEPLOY_DIR/"
        ${pkgs.coreutils}/bin/chown "$TOMCAT_USER:$TOMCAT_GROUP" "$DEPLOY_DIR/${name}.lex"
        ${pkgs.coreutils}/bin/chmod 0644 "$DEPLOY_DIR/${name}.lex"
        echo "Successfully deployed ${name}.lex"
      else
        echo "Warning: Extension file not found for ${name}"
      fi
    '') extensions)}

    ${pkgs.coreutils}/bin/ls -l "$DEPLOY_DIR/"
  '';
}
