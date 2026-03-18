{
  pkgs,
  lucee,
  extensions,
  cfConfig,
  project,
  webapp,
  isMasa,
  LUCEE_JAVA_OPTS,
  javaPackage,
  tag,
  name,
  imageConfig,
}:

let
  cfConfigJSON = pkgs.writeText "cfconfig-prod-template.json" (builtins.toJSON cfConfig);

  CATALINA_HOME = lucee;
  JAVA_HOME = javaPackage;
  CATALINA_BASE = "/opt/lucee";
  CLASSPATH = "$CATALINA_BASE/lib/*:$CATALINA_HOME/lib/*";

  loggingProperties = pkgs.writeText "logging.properties" ''
    handlers = java.util.logging.ConsoleHandler
    .level = INFO

    java.util.logging.ConsoleHandler.level = INFO
    java.util.logging.ConsoleHandler.formatter = java.util.logging.SimpleFormatter
    java.util.logging.SimpleFormatter.format = %1$tF %1$tT %4$s %2$s %5$s%6$s%n

    org.apache.catalina.core.ContainerBase.[Catalina].level = INFO
    org.apache.catalina.core.ContainerBase.[Catalina].handlers = java.util.logging.ConsoleHandler
  '';

  healthCheckFile = pkgs.writeText "health-index.cfm" ''
    <cfoutput>OK</cfoutput>
  '';

  healthCheckScript = pkgs.writeShellScript "health-check.sh" ''
    #!${pkgs.dash}
    set -e

    ${
      if isMasa then
        ''
          # For Masa CMS, check for "Document Moved" from root, this means all masa initialization has worked
          if curl --max-time 15 "http://localhost:8888/" 2>/dev/null | grep -q "Document Moved"; then
            exit 0
          else
            exit 1
          fi
        ''
      else
        ''
          curl -f --max-time 10 "http://localhost:8888/health/"
        ''
    }
  '';

  buildTimeSetupScript = pkgs.writeShellScript "build-setup.sh" ''
    #!${pkgs.dash}
    set -euo pipefail

    echo "=== Setting up Lucee for production deployment ==="
    mkdir -p /opt/lucee/{conf,webapps,logs,temp,work,lucee-server/deploy}
    cp -r ${lucee}/* /opt/lucee/
    ln -sf /app /opt/lucee/webapps/ROOT

    # Deploy Lucee extensions
    ${pkgs.lib.concatMapStringsSep "\n    " (
      ext: "cp -f ${ext}/*.lex /opt/lucee/lucee-server/deploy/"
    ) extensions}

    mkdir -p /opt/lucee/webapps/health
    cp ${cfConfigJSON} /opt/lucee/lucee-server/deploy/.CFConfig.json
    ${
      pkgs.lib.optionalString isMasa == false "cp ${healthCheckFile} /opt/lucee/webapps/health/index.cfm"
    }
    cp ${healthCheckScript} /opt/lucee/health-check.sh
    cp ${loggingProperties} /opt/lucee/conf/logging.properties

    chmod +x /opt/lucee/health-check.sh
    chown -R lucee:lucee /opt/lucee
    chown -R lucee:lucee /app

    # warmup
    export CATALINA_HOME=${CATALINA_HOME}
    export CATALINA_BASE=${CATALINA_BASE}
    export JAVA_HOME=${JAVA_HOME}
    export CLASSPATH=${CLASSPATH}
    export LUCEE_ENABLE_WARMUP=1
    $CATALINA_BASE/bin/catalina.sh run
    echo "=== Lucee setup completed ==="
  '';

  containerInitScript = pkgs.writeShellScriptBin "container-init.sh" ''
    #!${pkgs.dash}
    set -euo pipefail

    echo "Starting ${project} Lucee Container..."

    required_vars=("DATABASE_HOST" "DATABASE_PORT" "DATABASE_USERNAME" "DATABASE_PASSWORD")
    for var in "''${required_vars[@]}"; do
      if [ -z "''${!var:-}" ]; then
        echo "ERROR: Required environment variable $var is not set"
        exit 1
      fi
    done

    export LUCEE_JAVA_OPTS="${LUCEE_JAVA_OPTS}"
    export LOG_LEVEL="''${LOG_LEVEL:-INFO}"
    export TZ="''${TZ:-Europe/Zurich}"

    export CATALINA_HOME=${CATALINA_HOME}
    export CATALINA_BASE=${CATALINA_BASE}
    export JAVA_HOME=${JAVA_HOME}
    export CLASSPATH=${CLASSPATH}

    ${pkgs.lib.optionalString isMasa ''
      # Create writable cache directories for all sites otherwise masaCMS cries
      for site_dir in /app/sites/*; do
        if [ -d "$site_dir" ]; then
          chmod 755 "$site_dir"
          cache_dir="$site_dir/cache"
          mkdir -p "$cache_dir"
          chmod 755 "$cache_dir"
        fi
      done
    ''}

    _term() {
      echo "Received SIGTERM, shutting down gracefully..."
      $CATALINA_BASE/bin/catalina.sh stop
      exit 0
    }
    trap _term SIGTERM SIGINT

    echo "Starting Lucee server..."
    echo "Java Options: $LUCEE_JAVA_OPTS"
    echo "Database Host: $DATABASE_HOST:$DATABASE_PORT"

    exec $CATALINA_BASE/bin/catalina.sh run
  '';

in
pkgs.dockerTools.buildImage {
  inherit tag name;

  # Create a non-root user and run build-time setup
  runAsRoot = ''
    #!${pkgs.runtimeShell}
    ${pkgs.dockerTools.shadowSetup}
    groupadd -r lucee
    useradd -r -g lucee -d /opt/lucee -s ${pkgs.lib.getExe pkgs.bash}h lucee
    mkdir -p /opt/lucee /app
    chown lucee:lucee /opt/lucee

    echo "=== Running Lucee Build-Time Setup ==="
    ${buildTimeSetupScript}
  '';

  copyToRoot = pkgs.buildEnv {
    name = "container-root";
    paths = with pkgs; [
      dash
      coreutils
      curl
      gawk
      gnugrep
      gnused
      procps
      gettext

      # Application files
      javaPackage
      lucee

      # Application wwwroot directory
      (pkgs.runCommand "copy-wwwroot" { } ''
        mkdir -p $out/app
        cp -r ${webapp}/** $out/app/
      '')
    ];
  };

  config = {
    Cmd = [ "${containerInitScript}/bin/container-init.sh" ];
    ExposedPorts = {
      "8888/tcp" = { };
    };
    Env = [
      "JAVA_HOME=${pkgs.openjdk25}"
      "PATH=/bin:${pkgs.openjdk25}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin"
      "CATALINA_HOME=${lucee}"
      "CATALINA_BASE=/opt/lucee"
    ];
    User = "lucee";
    WorkingDir = "/opt/lucee";

    # Health check configuration
    Healthcheck = {
      Test = [
        "CMD"
        "/opt/lucee/health-check.sh"
      ];
      Interval = 30000000000; # 30 seconds in nanoseconds
      Timeout = 15000000000; # 15 seconds in nanoseconds
      Retries = 3;
      StartPeriod = 20000000000; # 20 seconds in nanoseconds
    };
  }
  // imageConfig;
}
