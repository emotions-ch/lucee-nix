{ pkgs
, image # a derivation produced by mkLuceeDockerImage
, name ? "lucee-image-health"
, containerName ? "lucee"
, port ? 8888
, backend ? "podman"
, environment ? { } # merged over the dummy DATABASE_* values below
, healthPath ? "/health/"
, expect ? "OK"
, memorySize ? 4096
, diskSize ? 16384
, cores ? 2
, requireKvm ? true
, bootTimeout ? 600
, extraTestScript ? ""
, # Whether this image's readiness probe requires a database. Read off the image
  # by default; only pass it explicitly for images not built by mkLuceeDockerImage.
  isMasa ? image.luceeIsMasa or false
,
}:

let
  inherit (pkgs) lib;

  # Never hardcode this: streamLayeredImage lowercases `name`, and podman only
  # skips the registry if the ref matches the image's RepoTag exactly.
  imageRef = "${image.imageName}:${image.imageTag}";
  unit = "${backend}-${containerName}.service";

  # Only meaningful for Masa images. For everything else --readiness is defined
  # as --liveness, so it passes without a database and this would assert the
  # opposite of the truth.
  readinessSubtest = lib.optionalString isMasa ''

    with subtest("readiness still requires the database"):
        # The container HEALTHCHECK runs --readiness. If that ever started
        # passing without a database, orchestrators would route traffic at a
        # Masa instance that cannot serve.
        machine.fail(
            "${backend} exec ${containerName} /opt/lucee/health-check.sh --readiness"
        )
  '';

  test = pkgs.testers.runNixOSTest {
    inherit name;

    nodes.machine = { ... }: {
      virtualisation = {
        # None of these are optional. diskSize defaults to 1024 MiB, and a
        # multi-hundred-MB image unpacks to several GB in podman's
        # store; the default single core plus a JVM boot runs close to the
        # test driver's timeouts.
        inherit memorySize diskSize cores;

        oci-containers = {
          inherit backend;
          containers.${containerName} = {
            image = imageRef;
            # streamLayeredImage yields a script, not a tarball: this pipes it
            # into `<backend> load` in ExecStartPre. No registry either way.
            imageStream = image;
            pull = "never";
            ports = [ "127.0.0.1:${toString port}:${toString port}" ];
            environment = {
              # The container init script refuses to start unless these are
              # non-empty. Nothing connects with them: the datasource is lazy.
              DATABASE_HOST = "127.0.0.1";
              DATABASE_PORT = "1433";
              DATABASE_USERNAME = "dummy";
              DATABASE_PASSWORD = "dummy";
              TZ = "Europe/Zurich";
            } // environment;
          };
        };
      };

      environment.systemPackages = [ pkgs.curl ];
    };

    testScript = ''
      start_all()

      machine.wait_for_unit("${unit}", timeout=${toString bootTimeout})
      machine.succeed(
          "${backend} inspect -f '{{.State.Running}}' ${containerName} | grep -q true"
      )
      machine.wait_for_open_port(${toString port}, timeout=${toString bootTimeout})

      with subtest("lucee serves the database-independent health context"):
          machine.wait_until_succeeds(
              "curl -fsS --max-time 10 "
              "http://127.0.0.1:${toString port}${healthPath} | grep -q '${expect}'",
              timeout=${toString bootTimeout},
          )

      with subtest("image ships a working liveness probe"):
          machine.succeed(
              "${backend} exec ${containerName} test -x /opt/lucee/health-check.sh"
          )
          machine.succeed(
              "${backend} exec ${containerName} /opt/lucee/health-check.sh --liveness"
          )
      ${readinessSubtest}
      ${extraTestScript}

      # The old CI step dumped `docker logs --tail 100` on failure; keep that
      # affordance, unconditionally, so a red build is debuggable from the log.
      print(machine.execute("journalctl -u ${unit} --no-pager -n 300")[1])
    '';
  };
in
if requireKvm then
  test
else
# qemu already falls back to TCG (accel=kvm:tcg); this only drops the
# scheduling constraint so a builder without /dev/kvm will accept the job.
# overrideTestDerivation is used rather than `requiredFeatures.kvm = false`
# because the latter only exists in newer nixpkgs.
  test.overrideTestDerivation (prev: {
    requiredSystemFeatures = lib.remove "kvm" (prev.requiredSystemFeatures or [ ]);
  })
