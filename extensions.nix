{ lib, pkgs }:

let
  mkLuceeExtension = { name, version, sha256 ? lib.fakeHash }: pkgs.stdenv.mkDerivation {
    inherit version name;
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
      version = "3.0.4";
      sha256 = "1cccdqa15cafi1q4xnfmq69bq7saxl84jiwjb41mjhpmji0dsnz9";
    };

    image-extension = mkLuceeExtension {
      name = "image-extension";
      version = "3.0.0.6";
      sha256 = "1ddi5d96iinqfzrb8f17hp0ddckas7yx2qvjqkr9pw7wh4pn0cjv";
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
