{ inputs, ... }:

{
  imports = [inputs.lucee-example.nixosModules.lucee];

  services.lucee = {
    enable = true;
    port = 8080;
    openFirewall = true;
    # instancePath = "${inputs.lucee-example}/lucee-instance";

    javaOpts = [
      "-Xmx1024m"
      "-Xms512m"
    ];
  };
}

