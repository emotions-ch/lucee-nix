{
  description = "My Lucee Project - Development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    lucee-nix = {
      url = "github:emotions-ch/lucee-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs
    , flake-utils
    , lucee-nix
    , ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ lucee-nix.overlays.default ];
        };

        # Create Lucee server instance
        lucee = pkgs.mkTomcatLucee { };

        # Project configuration
        project = "myproject";

        cfConfig = {
          dataSources.${project} = {
            name = project;
            class = "org.postgresql.Driver";
            bundleName = "org.postgresql.jdbc";
            dsn = "jdbc:postgresql://{host}:{port}/{database}";
            username = "devuser";
            password = "\${DATASOURCE_SECRET}";
            host = "localhost";
            database = project;
            port = "5432";
            # ... additional configuration
          };
        };

        # extensions requiured by your application
        extensions = with pkgs.luceeExtensions; [
          "org.postgresql.jdbc"
          image-extension
          administrator-extension
        ];
      in
      {
        # Production Docker image
        packages.dockerImage = pkgs.mkLuceeDockerImage {
          inherit lucee project;
          extensions = extensions;
          cfConfig = cfConfig;
          webapp = ./wwwroot;

          # Performance tuning
          LUCEE_JAVA_OPTS = "-Xms256m -Xmx1024m -XX:+UseG1GC";

          # Container registry configuration
          name = "ghcr.io/myorg/${project}";
          tag = "v1.0.0";

          imageConfig = {
            Labels = {
              "org.opencontainers.image.source" = "https://github.com/myorg/${project}";
              "org.opencontainers.image.description" = "My Lucee Application";
            };
          };
        };
      }
    );
}
