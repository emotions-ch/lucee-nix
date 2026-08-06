# CI for lucee-nix projects

The short version: **put everything in `checks`, and point CI at it.**

```nix
checks = pkgs.mkLuceeChecks {
  src = ./.;
  name = project.name;
  image = dockerImage;
};
```

```bash
nix flake check -L
```

That one command is the whole pipeline. Developers get the same verdict locally
that CI gets, and CI needs no bespoke steps that only exist in one vendor's YAML.

`mkLuceeChecks` gives you a formatting check and `image-health`, the image boot
test described below. The image itself is not repeated as a check — CI should
build `packages.*` alongside `checks.*`, and `image-health` depends on it anyway.

## What a health check can and cannot cover

The instinct is to reproduce production: run the container with real database
credentials and wait for `docker inspect` to report `healthy`. That does not work
inside a Nix build, and it is worth being precise about why, because the
constraint is not arbitrary.

A Nix build sandbox has **no network** and **no secrets**. So a build-time check
cannot reach a database, full stop. Trying to force it — `__noChroot`, impure
derivations, credentials read from a host path — trades away the property that
makes the check worth having: that its result is a pure function of its inputs,
cacheable, and identical on every machine.

Split the concerns instead:

| | Covered by | Runs where |
| --- | --- | --- |
| image boots, Tomcat starts, Lucee compiles and serves CFML, extensions deploy, runtime user can read its own state | `mkLuceeImageTest` | build time, every commit, hermetic |
| the database is reachable and the app bootstraps against it | `health-check.sh --readiness` / the container `HEALTHCHECK` | deploy time, against a host with network reach |

The first tier is the one that catches regressions you introduced. The second is
mostly an environment assertion — it tells you the database is up and the
credentials are right, which is a deployment property, not a property of the
commit. Running it in CI also means CI needs production credentials, which is a
meaningful cost for what it buys.

`mkLuceeImageTest` probes `/health/`, which every image deploys as its own Tomcat
context with no `Application.cfc` in its lookup chain. It therefore answers even
with no database in sight. See [Liveness vs. readiness](../README.md#liveness-vs-readiness).

## Gradient

[Gradient](https://github.com/wavelens/gradient) evaluates a wildcard over your
flake outputs and builds the resulting derivations. There are no shell steps and
no build secrets — which is precisely why the `checks`-shaped pipeline above fits
it without adaptation.

The default wildcard is `packages.<system>.*`, which does **not** include
`checks` — so by default the health test never runs. Point Gradient at the checks
as well:

```nix
{
  wildcard = "checks.x86_64-linux.*";
}
```

Building both `packages.*` and `checks.*` is the intended setup: the packages
wildcard covers the image and any other artifacts, the checks wildcard covers
formatting and the boot test. `image-health` depends on the image regardless, so
it is never skipped.

Gradient cannot push to a container registry (no secrets, no steps). If you rely
on that, either keep a minimal publishing job elsewhere, or consume the image
from Gradient's own binary cache via its deployment module.

## GitHub Actions

```yaml
- uses: cachix/install-nix-action@v24
- run: nix flake check -L
```

Two caveats specific to hosted runners:

- `mkLuceeImageTest` needs `/dev/kvm`. So does `mkLuceeDockerImage` itself, via the
  build-time warmup, so if your image builds on a runner the test will run there
  too. If you land on a runner without it, set `requireKvm = false` and accept
  slow TCG emulation.
- If your database is on a private network, a hosted runner cannot reach it —
  which is the usual reason the old "run the container against the real database"
  step was quietly broken. The hermetic test has no such problem.
