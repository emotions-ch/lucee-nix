{ lib, pkgs }:

let
  mkLuceeExtension = {
    name,
    description ? "Lucee Extension",
    version,
    sha256 ? lib.fakeHash
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

    imageExtension = mkLuceeExtension {
      name = "image-extension";
      description = "Lucee Image Extension provides essential image manipulation tags and functions (cfimage, imageCrop, imageNew, etc.) for Lucee 7+ running on Jakarta EE containers. This version requires Lucee 7 and is compatible with Tomcat 10+. For Lucee 6 installations, please use Image Extension 2.x instead.";
      version = "3.0.0.6";
      sha256 = "1ddi5d96iinqfzrb8f17hp0ddckas7yx2qvjqkr9pw7wh4pn0cjv";
    };

    luceeAdministrator = mkLuceeExtension {
      name = "administrator-extension";
      description = "Core Extension to integrate the Lucee Administrator into Lucee.";
      version = "1.0.0.6";
      sha256 = "0181pq87max0nzc3y01agxvrapmzp7nwb4mwghz9hn6nr7idqdlg";
    };

    luceeDocumentation = mkLuceeExtension {
      name = "documentation-extension";
      description = "Core Extension to integrate the Lucee Documentation into Lucee.";
      version = "1.0.0.5";
      sha256 = "1m69h1x4vvnsqwkrjagnizyj5cmvycg6sf1xjvqvajzngn16dw9h";
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

    echo "Extension deployment completed. Files in $DEPLOY_DIR:"
    ${pkgs.coreutils}/bin/ls -la "$DEPLOY_DIR/"
  '';
}
