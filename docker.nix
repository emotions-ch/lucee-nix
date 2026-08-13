{ pkgs
, lucee
, extensions
, cfConfig
, project
, webapp
, isMasa
, LUCEE_JAVA_OPTS
, javaPackage
, tag
, name
, imageConfig
,
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

  # Fixes Masa needs to run on our Lucee builds. Kept as patches rather than
  # forked files so a Masa upgrade in a project fails loudly (patch refuses to
  # apply) instead of silently reintroducing the bug.
  # you should probably still install the extesion but for some reason it only seems to heppen in docker so like
  # ¯\_(ツ)_/¯
  masaPatches = [ ./patches/masa-portcullis-urlencode.patch ];

  applyMasaPatches = pkgs.lib.concatMapStringsSep "\n"
    (patchFile: ''
      if ${pkgs.lib.getExe pkgs.patch} -p1 -d /app -R -f --dry-run --silent < ${patchFile} >/dev/null 2>&1; then
        echo "  skip (already applied): ${baseNameOf patchFile}"
      else
        echo "  apply: ${baseNameOf patchFile}"
        ${pkgs.lib.getExe pkgs.patch} -p1 -d /app < ${patchFile}
      fi
    '')
    masaPatches;

  healthCheckFile = pkgs.writeText "health-index.cfm" ''
    <cfoutput>OK</cfoutput>
  '';

  healthCheckScript = pkgs.writeShellScript "health-check.sh" ''
    set -eu

    liveness() {
      curl -fsS --max-time 10 "http://localhost:8888/health/" | grep -q "OK"
    }

    readiness() {
    ${
      if isMasa then
        ''
          # For Masa CMS, check for "Document Moved" from root, this means all masa initialization has worked
          curl -sS --max-time 15 "http://localhost:8888/" 2>/dev/null | grep -q "Document Moved"
        ''
      else
        ''
          liveness
        ''
    }
    }

    case "''${1:---readiness}" in
      --liveness) liveness ;;
      --readiness) readiness ;;
      *)
        echo "usage: health-check.sh [--liveness|--readiness]" >&2
        exit 2
        ;;
    esac
  '';

  buildTimeSetupScript = pkgs.writeShellScript "build-setup.sh" ''
    set -euo pipefail

    echo "=== Setting up Lucee for production deployment ==="

    # CATALINA_BASE only needs the writable pieces. bin/, lib/ and lucee/ stay in
    # CATALINA_HOME (${lucee}), which conf/catalina.properties already points
    # common.loader at. Copying the whole tree duplicated ~34MB into the one
    # layer that changes on every build.
    mkdir -p /opt/lucee/{lib,webapps,logs,temp,work,server/lucee-server/deploy}

    install -d -m 0755 /opt/lucee/conf
    install -m 0644 -t /opt/lucee/conf ${lucee}/conf/*

    ln -sf /app /opt/lucee/webapps/ROOT

    # Deploy Lucee extensions
    ${pkgs.lib.concatMapStringsSep "\n    " (
      ext: "cp -f ${ext}/*.lex /opt/lucee/server/lucee-server/deploy/"
    ) extensions}

    mkdir -p /opt/lucee/webapps/health
    cp ${healthCheckFile} /opt/lucee/webapps/health/index.cfm

    install -m 0644 ${cfConfigJSON} /opt/lucee/server/lucee-server/deploy/.CFConfig.json
    install -m 0755 ${healthCheckScript} /opt/lucee/health-check.sh
    install -m 0644 ${loggingProperties} /opt/lucee/conf/logging.properties

    # warmup
    export CATALINA_HOME=${CATALINA_HOME}
    export CATALINA_BASE=${CATALINA_BASE}
    export JAVA_HOME=${JAVA_HOME}
    export CLASSPATH=${CLASSPATH}
    export LUCEE_ENABLE_WARMUP=1
    $CATALINA_HOME/bin/catalina.sh run

    # Must run *after* the warmup: catalina runs as (fake)root here and
    # materializes /opt/lucee/{server,work,conf/Catalina} as root:root 0750,
    # which the runtime user (config.User = "lucee") could then not read.
    chown -R lucee:lucee /opt/lucee /app
    echo "=== Lucee setup completed ==="
  '';

  containerInitScript = pkgs.writeShellScriptBin "container-init.sh" ''
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
      $CATALINA_HOME/bin/catalina.sh stop
      exit 0
    }
    trap _term SIGTERM SIGINT

    echo "Starting Lucee server..."
    echo "Java Options: $LUCEE_JAVA_OPTS"
    echo "Database Host: $DATABASE_HOST:$DATABASE_PORT"

    exec $CATALINA_HOME/bin/catalina.sh run
  '';

  containerRoot = pkgs.buildEnv {
    name = "container-root";
    paths = with pkgs; [
      dockerTools.binSh
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
    ];
  };

in
pkgs.dockerTools.streamLayeredImage {
  inherit tag name;

  contents = [ containerRoot ];

  # The build-time warmup needs absolute paths (CATALINA_BASE=/opt/lucee is baked
  # into the config it produces), so the plain fakeroot environment is not enough.
  enableFakechroot = true;
  fakeRootCommands = ''
    # buildEnv links a top-level directory wholesale when exactly one package
    # provides it, and gawk is the only one here shipping /etc. That leaves /etc
    # as a symlink into the read-only store, which shadowSetup cannot write to -
    # and neither can docker/podman, which bind-mount /etc/hosts and
    # /etc/resolv.conf into the container at runtime. Materialize it.
    if [ -L /etc ]; then
      etc_src="$(readlink -f /etc)"
      rm /etc
      mkdir -m 0755 /etc
      cp -aL --no-preserve=mode,ownership "$etc_src"/. /etc/
      chown -R 0:0 /etc
    fi

    ${pkgs.dockerTools.shadowSetup}
    groupadd -r -g 999 lucee
    useradd -r -u 999 -g lucee -d /opt/lucee -s ${pkgs.lib.getExe pkgs.bash} lucee
    mkdir -p /opt/lucee
    chown lucee:lucee /opt/lucee

    mkdir -m 0755 -p /app
    cp -a ${webapp}/. /app/
    chmod -R u+w /app

    ${pkgs.lib.optionalString isMasa ''
      echo "=== Applying Masa patches ==="
      ${applyMasaPatches}
    ''}

    echo "=== Running Lucee Build-Time Setup ==="
    ${buildTimeSetupScript}
  '';

  # Consumers (mkLuceeImageTest) need to know which readiness semantics this image
  # has, and asking the image beats making every project restate it.
  passthru.luceeIsMasa = isMasa;

  config = {
    Cmd = [ "${containerInitScript}/bin/container-init.sh" ];
    ExposedPorts = {
      "8888/tcp" = { };
    };
    Env = [
      "JAVA_HOME=${javaPackage}"
      "PATH=/bin:${javaPackage}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin"
      "CATALINA_HOME=${lucee}"
      "CATALINA_BASE=/opt/lucee"
    ];
    User = "lucee";
    WorkingDir = "/opt/lucee";

    Healthcheck = {
      Test = [
        "CMD"
        "/opt/lucee/health-check.sh"
        "--readiness"
      ];
      Interval = 30000000000; # 30 seconds in nanoseconds
      Timeout = 15000000000; # 15 seconds in nanoseconds
      Retries = 3;
      StartPeriod = 20000000000; # 20 seconds in nanoseconds
    };
  }
  // imageConfig;
}
