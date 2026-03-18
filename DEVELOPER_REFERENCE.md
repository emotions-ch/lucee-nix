# Lucee-Nix

A Nix flake, providing declarative infrastructure for [Lucee Server](https://www.lucee.org/) (CFML engine) development & deployments.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [API Reference](#api-reference)
   - [Core Functions](#core-functions)
   - [Extension Functions](#extension-functions)
   - [Docker Functions](#docker-functions)
3. [Configuration Reference](#configuration-reference)
   - [CFConfig Schema](#cfconfig-schema)
   - [Environment Variables](#environment-variables)
   - [Docker Configuration](#docker-configuration)
4. [Examples & Use Cases](#examples--use-cases)
   - [Development Setup](#development-setup)
   - [Production Deployment](#production-deployment)
5. [Advanced Topics](#advanced-topics)
   - [CI/CD Integration](#cicd-integration)

## Architecture Overview

The Lucee-Nix flake provides a modern, infrastructure-as-code approach to deploying CFML applications using Nix's reproducible build system. It uses **overlay patterns** to extend nixpkgs with Lucee-specific functionality.

### Core Design Patterns

- **Nix Overlays**: Extends nixpkgs without modifying core packages
- **Passthru Attributes**: Metadata flows through derivations for automatic dependency resolution
- **Declarative Configuration**: All infrastructure defined in Nix expressions
- **Environment Inheritance**: Development configurations extend to production with selective overrides
- **Single Mode Deployment**: Optimized for Lucee's single-mode architecture
- **Designed for Lucee 7 zero**: Designed for use with Lucee 7 (tho any version < 5.2 should work, `cfConfig` will only apply for < 6 )

### Key Components

```
lucee-nix/
├── flake.nix           # Main flake configuration and overlay definition
├── lucee.nix           # Core Lucee packaging logic
├── docker.nix          # Docker image building functionality  
├── extensions/         # Extension management system
│   ├── default.nix     # Extension builder functions
│   └── definitions.nix # Pre-defined extension catalog
│
└── examples/           # Complete usage examples
    ├── flake.example.nix
    └── production.env.example
```

---

## API Reference

### Core Functions

#### `mkTomcatLucee`

Creates a Tomcat server instance configured with Lucee Server.

```nix
mkTomcatLucee {
  baseDir ? "webapps/ROOT/";     # Web application base directory
  port ? 8888;                   # HTTP port for development server  
  luceeJar ? "lucee7-zero";      # Lucee JAR version identifier
  tomcatPackage ? <auto>;        # Tomcat package (auto-selected based on luceeJar)
}
```

**Parameters:**

- **`baseDir`** (string, optional): Directory containing your web application files. Defaults to `"webapps/ROOT/"`.
- **`port`** (integer, optional): HTTP port for the development server. Defaults to `8888`.
- **`luceeJar`** (string, optional): Lucee JAR version to use. Available options:
  - `"lucee7-zero"` (default) - Lucee 7.0.1.100 without bundled extensions
- **`tomcatPackage`** (package, optional): Tomcat package to use. Auto-selected based on `luceeJar` compatibility:
  - Lucee 7.x → Tomcat 11 (Java 25 compatible)

**Returns:** A derivation containing a configured Tomcat+Lucee server instance.

**Passthru Attributes:**
- `tomcatPackage` - The Tomcat package used
- `javaVersion` - Required Java version for compatibility

**Example:**
```nix
let
  luceeServer = pkgs.mkTomcatLucee {
    baseDir = "wwwroot";
    port = 8080;
  };
in
{
  # Use in development shell
  devShells.default = pkgs.mkShell {
    buildInputs = [ luceeServer ];
  };
}
```

---

### Extension Functions

#### `mkLuceeExtension`

Downloads a Lucee extension (.lex file) from the [official Lucee extension repository](https://download.lucee.org/#ext).

```nix
mkLuceeExtension {
  name;                         # Extension name (required)
  description ? "";             # Human-readable description
  version;                      # Extension version (required) 
  sha256 ? lib.fakeHash;        # SHA256 hash for reproducible builds
}
```

**Parameters:**

- **`name`** (string, required): Extension identifier used in the download URL
- **`description`** (string, optional): Human-readable description of the extension
- **`version`** (string, required): Specific version to download
- **`sha256`** (string, optional): SHA256 hash of the extension file for verification. Run `nix-prefetch-url [url]` to generate the right hash.

**Returns:** A derivation containing the .lex extension file.

**Download URL Pattern:** `https://ext.lucee.org/{name}-{version}.lex`

**Example:**
```nix
myExtension = pkgs.mkLuceeExtension {
  name = "org.postgresql.jdbc";
  description = "PostgreSQL JDBC Driver";
  version = "42.7.7";
  sha256 = "0yd0n2ngwqf536knslpmhi3pixqnxfm0rk3jxy8abvihq9mdri4l";
};
```

#### `luceeExtensions`

Pre-built catalog of commonly used Lucee extensions.

**Available Extensions:**

To see all available extensions and their versions:

```bash
# List extension names
nix eval --impure --expr 'let flake = builtins.getFlake "github:emotions-ch/lucee-nix"; pkgs = import <nixpkgs> { overlays = [ flake.overlays.default ]; }; in builtins.attrNames pkgs.luceeExtensions'

# List extensions with versions
nix eval --impure --expr 'let flake = builtins.getFlake "github:emotions-ch/lucee-nix"; pkgs = import <nixpkgs> { overlays = [ flake.overlays.default ]; }; in builtins.mapAttrs (name: ext: ext.version) pkgs.luceeExtensions' --json
```

**Usage:**
```nix
extensions = [
  pkgs.luceeExtensions."org.postgresql.jdbc"
  pkgs.luceeExtensions.image-extension  
  pkgs.luceeExtensions.compress
];
```

---

### Docker Functions

#### `mkLuceeDockerImage`

Creates production-ready Docker images for Lucee applications with security best practices and operational features.

```nix
mkLuceeDockerImage {
  lucee;                                    # Tomcat+Lucee instance (required)
  extensions ? [];                          # List of Lucee extensions
  cfConfig;                                 # CFConfig configuration object (required)
  project;                                  # Project name (required)
  webapp;                                   # Path to webapp directory (required)
  isMasa ? false;                           # Required for Masa CMS applications
  LUCEE_JAVA_OPTS ? "-Xms64m -Xmx512m";     # JVM options
  javaPackage ? pkgs.openjdk25;             # Java runtime package
  tag ? "latest";                           # Docker image tag
  name ? project;                           # Docker image name
  imageConfig ? {};                         # Additional Docker image configuration
}
```

**Parameters:**

- **`lucee`** (derivation, required): Tomcat+Lucee instance from `mkTomcatLucee`
- **`extensions`** (list, optional): List of Lucee extension derivations to install
- **`cfConfig`** (attrset, required): CFConfig configuration object (see [CFConfig Schema](#cfconfig-schema))
- **`project`** (string, required): Project identifier used for naming and configuration
- **`webapp`** (path, required): Path to directory containing your CFML application files
- **`isMasa`** (boolean, optional): Enable Masa CMS-specific optimizations (cache directories, permissions)
- **`LUCEE_JAVA_OPTS`** (string, optional): JVM memory and runtime options
- **`javaPackage`** (package, optional): Java runtime package to use
- **`tag`** (string, optional): Docker image tag for versioning
- **`name`** (string, optional): Docker image repository name
- **`imageConfig`** (attrset, optional): Additional Docker image configuration [Docker image configuration](#docker-configuration)

**Returns:** A Docker image derivation ready for container deployment.

**Container Features:**
- **Security**: Runs as non-root `lucee` user (UID 1000)
- **Health Checks**: HTTP endpoint monitoring on `/` for Masa applications and `/health/` for non-Masa applications
- **Signal Handling**: Proper SIGTERM/SIGINT handling for graceful shutdown
- **Configuration**: CFConfig JSON deployment with environment substitution
- **Extensions**: Automatic deployment of .lex files during build
- **Logging**: Structured logging with configurable levels

**Example:**
```nix
dockerImage = pkgs.mkLuceeDockerImage {
  inherit lucee extensions project;
  webapp = ./wwwroot;
  cfConfig = prodCfConfig;
  isMasa = true;
  
  # Container registry configuration
  name = "ghcr.io/myorg/myproject";
  imageConfig = {
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/myorg/myproject";
    };
  };
};
```

---

## Configuration Reference

### CFConfig Schema

CFConfig provides declarative Lucee server configuration through JSON. The lucee-nix flake supports the full CFConfig schema with environment variable substitution.

See [Lucee docs](https://docs.lucee.org/recipes/configuration.html) for config options.

### Environment Variables

#### Development Environment

```bash
# Catalina Configuration
CATALINA_HOME=/nix/store/...-tomcat-lucee
CATALINA_BASE=./lucee-instance
JAVA_HOME=/nix/store/...-openjdk25

# Database Secrets (file-based)
# Create files: {hostname}.secret containing database passwords
# Example: db.example.com.secret
```

#### Production Environment

```bash
# Required Database Configuration
DATABASE_USERNAME=myuser          # Database username
DATABASE_PASSWORD=secretpassword  # Database password  
DATABASE_HOST=db.example.com      # Database hostname
DATABASE_PORT=5432                # Database port

# Optional JVM Configuration
LUCEE_JAVA_OPTS="-Xms256m -Xmx1024m -XX:+UseG1GC"

# Optional Application Configuration  
TZ=UTC                            # Timezone
LUCEE_LOG_LEVEL=INFO              # Logging level
```

#### Environment Variable Substitution

CFConfig supports environment variable substitution using `${VARIABLE_NAME}` syntax:

```nix
cfConfig = {
  dataSources.myapp = {
    username = "\${DATABASE_USERNAME}";
    password = "\${DATABASE_PASSWORD}";
    host = "\${DATABASE_HOST}";
    port = "\${DATABASE_PORT}";
  };
};
```

### Docker Configuration

#### Container Image Configuration
For available options see: [opencontainers/image-spec](https://github.com/opencontainers/image-spec)

```nix
imageConfig = {
  # Container Labels (OCI Standard)
  Labels = {
    "org.opencontainers.image.title" = "My Lucee App";
    "org.opencontainers.image.description" = "CFML application";
    "org.opencontainers.image.source" = "https://github.com/myorg/myapp";
    "org.opencontainers.image.version" = "1.0.0";
    "org.opencontainers.image.created" = "2024-01-01T00:00:00Z";
  };
};
```

---

## Examples & Use Cases

### Development Setup

#### Basic Development Environment

```nix
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

  outputs = { nixpkgs, flake-utils, lucee-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ lucee-nix.overlays.default ];
        };

        # Create Lucee server instance
        lucee = pkgs.mkTomcatLucee {
          baseDir = "wwwroot";
          port = 8888;
        };

        # Project configuration
        project = "myproject";
        
        # Development database configuration
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

        # Required extensions
        extensions = with pkgs.luceeExtensions; [
          "org.postgresql.jdbc"
          image-extension
          administrator-extension
        ];

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Development tools
            nixpkgs-fmt
            statix
            
            # Runtime
            openjdk25
            
            # Project scripts
            startScript
            initScript
          ];
        };
        
        packages.default = lucee;
      }
    );
}
```

#### Development Scripts

The development environment includes automated scripts for Lucee instance management:

**Initialization Script (`init-lucee`):**
- Creates local Lucee instance directory
- Symlinks webapp directory to `webapps/ROOT`
- Configures Tomcat with proper permissions

**Start Script (`start-lucee`):**
- Validates database secret files
- Deploys extensions automatically
- Configures CFConfig with environment substitution
- Starts Tomcat with proper environment variables

### Production Deployment

#### Production Docker Image

```nix
{
  # Production configuration inherits from development
  prodCfConfig = {
    dataSources.${project} = (
      cfConfig.dataSources.${project} // {
        # Override with environment variables
        username = "\${DATABASE_USERNAME}";
        password = "\${DATABASE_PASSWORD}";
        host = "\${DATABASE_HOST}";
        port = "\${DATABASE_PORT}";
      }
    );
  };

  # Minimal extension set for production
  prodExtensions = with pkgs.luceeExtensions; [
    "org.postgresql.jdbc"  # Only required extensions
    image-extension
  ];

  # Production Docker image
  packages.dockerImage = pkgs.mkLuceeDockerImage {
    inherit lucee project;
    extensions = prodExtensions;
    cfConfig = prodCfConfig;
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
```

#### Container Deployment

```bash
# Build and load image
nix build .#dockerImage
docker load < result

# Run with environment configuration
docker run -d \
  --name myproject \
  -p 8080:8888 \
  -e DATABASE_USERNAME=produser \
  -e DATABASE_PASSWORD=secret \
  -e DATABASE_HOST=prod-db.example.com \
  -e DATABASE_PORT=5432 \
  ghcr.io/myorg/myproject:v1.0.0
```
---

## Advanced Topics

### CI/CD Integration

#### GitHub Actions Workflow

```yaml
# .github/workflows/build-and-deploy.yml
name: Build and Deploy

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Install Nix
      uses: cachix/install-nix-action@v27
      with:
        nix_path: nixpkgs=channel:nixos-unstable
    
    - name: Build Lucee application
      run: nix build .#default
    
    - name: Build Docker image
      run: nix build .#dockerImage
    
    - name: Load and test image
      run: |
        docker load < result
        docker run -d --name test-container \
          -e DATABASE_USERNAME=test \
          -e DATABASE_PASSWORD=test \
          -e DATABASE_HOST=localhost \
          -e DATABASE_PORT=5432 \
          $(docker images --format "table {{.Repository}}:{{.Tag}}" | tail -1)
        
        # Wait for health check
        sleep 30
        docker logs test-container
        
    - name: Push to Container Registry
      if: github.ref == 'refs/heads/main'
      run: |
        echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
        docker push ghcr.io/${{ github.repository }}:latest
```

#### Multi-Stage Deployment

```nix
# Different configurations for different environments
outputs = {
  packages = {
    # Development image with debugging tools
    dev-image = pkgs.mkLuceeDockerImage {
      inherit lucee extensions;
      cfConfig = devCfConfig;
      webapp = ./wwwroot;
      
      # Development JVM settings
      LUCEE_JAVA_OPTS = "-Xms64m -Xmx512m -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005";
      
      imageConfig.Env = [
        "LUCEE_LOG_LEVEL=DEBUG"
        "LUCEE_ENABLE_DEBUG=true"
      ];
    };
    
    # Staging image with monitoring
    staging-image = pkgs.mkLuceeDockerImage {
      inherit lucee extensions;
      cfConfig = stagingCfConfig;
      webapp = ./wwwroot;
      
      LUCEE_JAVA_OPTS = "-Xms256m -Xmx1024m -XX:+UseG1GC";
      name = "ghcr.io/myorg/myproject";
      tag = "staging";
    };
    
    # Production image optimized for performance
    prod-image = pkgs.mkLuceeDockerImage {
      inherit lucee;
      extensions = prodExtensions;  # Minimal extension set
      cfConfig = prodCfConfig;
      webapp = ./wwwroot;
      
      # Production JVM tuning
      LUCEE_JAVA_OPTS = "-Xms512m -Xmx2048m -XX:+UseG1GC -XX:MaxGCPauseMillis=100";
      name = "ghcr.io/myorg/myproject";
      tag = "latest";
      
      imageConfig = {
        Labels = {
          "org.opencontainers.image.title" = "MyProject Production";
          "org.opencontainers.image.source" = "https://github.com/myorg/myproject";
        };
      };
    };
  };
};
```
---

