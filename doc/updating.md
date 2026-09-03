# Updating Lucee

Lucee is built from source (`lucee/source.nix`) from a pinned commit of
[lucee/Lucee](https://github.com/lucee/Lucee). The pins live in
`lucee/source-definitions.nix` and are generated with `tools/update-lucee.sh`.

The old HTML-scraping updater (`tools/lucee-updater`) is gone: the redesign of
download.lucee.org made it silently emit empty catalogs. The replacement reads
machine-readable sources (Maven Central metadata, git refs, the core
MANIFEST.MF) and never writes files itself — every failure is loud, every
change goes through a human diff.

## Updating to a new Lucee release

1. List available releases:

   ```sh
   ./tools/update-lucee.sh
   ```

2. Generate the pin snippet for the version you want:

   ```sh
   ./tools/update-lucee.sh 7.0.4.34
   ```

   The script resolves the head of the *release branch* (e.g. `7.0.4`), checks
   that its `loader/pom.xml` carries the exact non-SNAPSHOT version (git tags
   point at `-SNAPSHOT` commits, the branch head is the real release), and
   prefetches the source tree plus every file the build's ant `<get>` tasks
   would download (the 12 required `.lex` extensions, testbox, the stable
   loader jar).

   If the release branch head has already moved past the release (its pom
   says the next `-SNAPSHOT`), find the release commit (`git log` on the
   branch, usually a commit named "release", or the tag's `^{}` commit) and
   pass it as the second argument.

3. Paste the snippet into `lucee/source-definitions.nix`. Attrs are keyed by
   full version (`lucee7_1_0_204`); if the new release is the new "Stable"
   on download.lucee.org, also bump the `aliases` set in `lucee/source.nix`
   (`lucee7`, `lucee7_0`, `lucee7_1`, ...).

4. Fill in `mvnDepsHash` by trust-on-first-use: leave the fake hash, run

   ```sh
   nix build .#legacyPackages.x86_64-linux.lucee-jars.lucee7-src
   ```

   and copy the `got: sha256-...` hash from the mismatch error into
   `mvnDepsHash`. Then build again — this run is fully offline and produces
   the full, light, and zero jars.

5. Sanity-check before committing:

   ```sh
   nix build .#checks.x86_64-linux.image-health
   ```

## Failure modes (all loud, by design)

- **`.lex` hash mismatch or 404** — one of the pinned extensions was
  republished upstream. `compress-extension` is pinned at a `-SNAPSHOT`
  version by Lucee itself, so this is expected eventually. Re-run
  `./tools/update-lucee.sh <version>` and take the new hash for that entry.
- **`mvnDepsHash` mismatch after a nixpkgs bump** — Maven repo layout
  nondeterminism. Extend the `find ... -delete` normalization list in
  `lucee/source.nix` (`mvnDeps.installPhase`) if a new metadata file type
  shows up; otherwise just re-TOFU the hash.
- **pom says `-SNAPSHOT` at the branch head** — the release branch moved past
  the release commit. Find the commit whose pom matches the release version
  (`git log` on the branch) and use its sha as `rev` manually.

## Prebuilt `-bin` jars (`lucee/definitions.nix`)

Only Lucee >= 7 is built from source. Older versions (lucee6) and
prebuilt-only artifacts (BETA builds) stay available as `-bin` attrs
(`lucee6-zero-bin`, `lucee7_1-BETA-zero-bin`, ...) fetched from
`https://cdn.lucee.org/<name>-<version>.jar`. To bump one, edit the version
in `lucee/definitions.nix` and TOFU the hash the same way.

## Extension catalog (`extensions/definitions.nix`)

The runtime extension catalog (`.lex` files placed into Docker images) is
still pinned by URL+hash from ext.lucee.org and updated by hand; the hashes
make any upstream change loud.
