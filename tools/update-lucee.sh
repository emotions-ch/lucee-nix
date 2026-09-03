#!/usr/bin/env bash
# Generate a lucee/source-definitions.nix entry for a Lucee release.
#
# Usage:
#   ./tools/update-lucee.sh                    # list available release versions
#   ./tools/update-lucee.sh 7.0.4.34           # print the pin snippet for a version
#   ./tools/update-lucee.sh 7.1.0.204 <rev>    # pin an explicit commit (when the
#                                              # release branch head moved on)
#
# Prints the finished attrset snippet to stdout; paste it into
# lucee/source-definitions.nix yourself. Deliberately not self-writing.
# The mvnDepsHash is left as a fake hash - build once and copy the real
# hash from the mismatch error (see doc/updating.md).
set -euo pipefail

MAVEN_META="https://repo1.maven.org/maven2/org/lucee/lucee/maven-metadata.xml"
REPO="https://github.com/lucee/Lucee"
RAW="https://raw.githubusercontent.com/lucee/Lucee"
EXT_MAVEN="https://repo1.maven.org/maven2/org/lucee"
EXT_CDN="https://cdn.lucee.org/org/lucee"

if [[ $# -eq 0 ]]; then
  echo "Available release versions (from Maven Central):" >&2
  curl -fsSL "$MAVEN_META" | sed -n 's/.*<version>\(.*\)<\/version>.*/\1/p' | grep -v -- '-RC\|-BETA\|-ALPHA\|-SNAPSHOT'
  exit 0
fi

version="$1"
branch="${version%.*}"

if [[ $# -ge 2 ]]; then
  rev="$2"
  echo "==> Using explicit rev $rev" >&2
else
  echo "==> Resolving head of release branch $branch" >&2
  rev=$(git ls-remote "$REPO" "refs/heads/$branch" | cut -f1)
  if [[ -z "$rev" ]]; then
    echo "ERROR: branch $branch not found on $REPO" >&2
    exit 1
  fi
  echo "    $rev" >&2
fi

echo "==> Verifying loader/pom.xml at $rev says $version (non-SNAPSHOT)" >&2
pom_version=$(curl -fsSL "$RAW/$rev/loader/pom.xml" | sed -n '/<artifactId>lucee<\/artifactId>/{n;s/.*<version>\(.*\)<\/version>.*/\1/p;}')
if [[ "$pom_version" != "$version" ]]; then
  echo "ERROR: pom at $rev says '$pom_version', expected '$version'." >&2
  echo "The release commit may not be the branch head; find the commit whose" >&2
  echo "pom matches (git log on the branch, or the release tag's ^{} commit)" >&2
  echo "and pass it as the second argument." >&2
  exit 1
fi

echo "==> Prefetching source tree" >&2
src_hash=$(nix flake prefetch "github:lucee/Lucee/$rev" --json | sed -n 's/.*"hash":"\([^"]*\)".*/\1/p')

prefetch() {
  nix store prefetch-file --json "$1" | sed -n 's/.*"hash":"\([^"]*\)".*/\1/p'
}

echo "==> Reading Require-Extension from core MANIFEST.MF" >&2
# unwrap 72-byte manifest continuation lines (leading space), then pull the key
extensions=$(curl -fsSL "$RAW/$rev/core/src/main/java/META-INF/MANIFEST.MF" \
  | sed -e ':a' -e 'N' -e '$!ba' -e 's/\r//g' -e 's/\n //g' \
  | sed -n 's/^Require-Extension: *//p' \
  | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep .)

# which repo ant fetches each extension from is hardcoded per extension in
# build-extensions.xml (src="${extURLMaven}${extFooGroupPath}..." vs
# ${extURLCDN}); the copies can differ between mirrors, so mirror the choice
build_ext=$(curl -fsSL "$RAW/$rev/ant/build-extensions.xml")
camelcase() {
  local out="" part
  for part in ${1//-/ }; do out+="${part^}"; done
  printf '%s' "$out"
}

cache_lines=""
while IFS=: read -r group artifact ext_version; do
  prop="ext$(camelcase "$artifact")GroupPath"
  if grep -q "extURLCDN}\${$prop}" <<<"$build_ext"; then
    base="cdn"
    url="$EXT_CDN/$artifact/$ext_version/$artifact-$ext_version.lex"
  elif grep -q "extURLMaven}\${$prop}" <<<"$build_ext"; then
    base="mvn"
    url="$EXT_MAVEN/$artifact/$ext_version/$artifact-$ext_version.lex"
  else
    echo "ERROR: no <get> for \${$prop} found in ant/build-extensions.xml" >&2
    echo "(the naming scheme may have changed; check the file at $rev)" >&2
    exit 1
  fi
  echo "==> Prefetching $artifact-$ext_version.lex ($base)" >&2
  hash=$(prefetch "$url")
  cache_lines+="        (lex $base \"$artifact\" \"$ext_version\" \"$hash\")\n"
done <<<"$extensions"

echo "==> Reading testbox/stableLoader pins from ant/build-core.xml" >&2
build_core=$(curl -fsSL "$RAW/$rev/ant/build-core.xml")
testbox_version=$(sed -n 's/.*name="testboxVersion" value="\([^"]*\)".*/\1/p' <<<"$build_core")
stable_loader=$(sed -n 's/.*name="stableLoader" value="\([^"]*\)".*/\1/p' <<<"$build_core")

testbox_url="https://downloads.ortussolutions.com/ortussolutions/testbox/$testbox_version/testbox-$testbox_version.zip"
stable_url="https://cdn.lucee.org/$stable_loader.jar"
echo "==> Prefetching testbox-$testbox_version.zip" >&2
testbox_hash=$(prefetch "$testbox_url")
echo "==> Prefetching $stable_loader.jar" >&2
stable_hash=$(prefetch "$stable_url")

attr="lucee${version//./_}"

cat <<EOF

  # --- paste into lucee/source-definitions.nix, adjust the attr name ---
  $attr = {
    version = "$version";
    rev = "$rev";
    srcHash = "$src_hash";
    # TOFU: build .#legacyPackages.<system>.lucee-jars.$attr once and
    # copy the real hash from the mismatch error
    mvnDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    javaVersion = 25;
    cacheEntries =
      let
        mvn = "$EXT_MAVEN";
        cdn = "$EXT_CDN";
        lex = base: artifact: version: hash: {
          name = "org.lucee-\${artifact}-\${version}.lex";
          url = "\${base}/\${artifact}/\${version}/\${artifact}-\${version}.lex";
          inherit hash;
        };
      in
      [
$(printf '%b' "$cache_lines" | sed 's/[[:space:]]*$//')
        {
          name = "testbox-$testbox_version.zip";
          url = "$testbox_url";
          hash = "$testbox_hash";
        }
        {
          name = "$stable_loader.jar";
          url = "$stable_url";
          hash = "$stable_hash";
        }
      ];
  };
EOF
