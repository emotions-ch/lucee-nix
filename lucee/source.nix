# Build Lucee from source (github:lucee/Lucee) instead of fetching the
# prebuilt jar from cdn.lucee.org.
#
# Maven drives the build but the real work happens in ant/build-core.xml,
# which compiles the Java core, boots the freshly built Lucee to compile the
# CFML sources into .lar archives, and assembles the fat jar. The light and
# zero jars are produced by the same in-build Lucee run (upload_to_s3.cfm's
# createLight()); without DO_DEPLOY/S3 credentials in the environment that
# script only builds the variants locally and never talks to S3.
#
# Two derivations per version:
#  - a fixed-output "mvn deps" derivation that runs the full build once with
#    network to capture ~/.m2 (buildMavenPackage-style)
#  - the real offline build, seeded with that .m2 plus a pre-populated
#    ${rootDir}/cache/ (linkFarm of pinned .lex/testbox/stable-loader files,
#    which turns every ant <get> into a no-op)
{ lib
, pkgs
}:

let
  jdk = pkgs.jdk21; # upstream builds with 21, bytecode targets 11
  maven = pkgs.maven.override { jdk_headless = jdk; };

  definitions = import ./source-definitions.nix;

  mkCache =
    entries:
    pkgs.linkFarm "lucee-build-cache" (
      map
        (e: {
          inherit (e) name;
          path = pkgs.fetchurl { inherit (e) url hash; };
        })
        entries
    );

  mkLuceeSourceBuild =
    { version
    , rev
    , srcHash
    , mvnDepsHash
    , cacheEntries
    , ...
    }:
    let
      src = pkgs.fetchFromGitHub {
        owner = "lucee";
        repo = "Lucee";
        inherit rev;
        hash = srcHash;
      };

      cache = mkCache cacheEntries;

      # - ${currentTime} only ends up in the lucee/version marker file inside
      #   the jar; pin it so rebuilds are stable.
      # - the test targets are gated with ant's if="testcases", which checks
      #   that the property is SET, not that it is true - so they can only be
      #   disabled by never defining it. Dropping the pom's <property> gives
      #   the same skip behaviour as upstream's `ant fast`. The CFML test
      #   suite would need live database services anyway.
      postPatch = ''
        substituteInPlace ant/build-utils.xml \
          --replace-fail 'new Date().getTime()' '"0"'
        substituteInPlace loader/pom.xml \
          --replace-fail '<property name="testcases" value="true" />' ""
      '';

      # testbox.lar is only consumed by the (skipped) test run
      mvnFlags = "-B -DcompileTestBox=false";

      seedBuildEnv = ''
        export HOME=$TMPDIR
        cp -rL ${cache} cache
        chmod -R u+w cache
      '';

      mvnDeps = pkgs.stdenv.mkDerivation {
        pname = "lucee-mvn-deps";
        inherit version src postPatch;
        nativeBuildInputs = [ jdk maven ];

        buildPhase = ''
          runHook preBuild
          ${seedBuildEnv}
          cd loader
          mvn package ${mvnFlags} -Dmaven.repo.local=$TMPDIR/m2
          cd ..
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          find $TMPDIR/m2 -type f \
            \( -name '*.lastUpdated' \
            -o -name 'resolver-status.properties' \
            -o -name '_remote.repositories' \
            -o -name 'maven-metadata-*.xml' \) -delete
          mkdir -p $out
          cp -r $TMPDIR/m2 $out/m2
          runHook postInstall
        '';

        dontFixup = true;
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = mvnDepsHash;
      };
    in
    pkgs.stdenv.mkDerivation {
      pname = "lucee-source";
      inherit version src postPatch;
      nativeBuildInputs = [ jdk maven ];

      passthru = { inherit mvnDeps cache; };

      buildPhase = ''
        runHook preBuild
        ${seedBuildEnv}
        cp -r ${mvnDeps}/m2 $TMPDIR/m2
        chmod -R u+w $TMPDIR/m2
        cd loader
        mvn package --offline ${mvnFlags} -Dmaven.repo.local=$TMPDIR/m2
        cd ..
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp loader/target/lucee-${version}.jar $out/lucee.jar
        cp loader/target/lucee-light-${version}.jar $out/lucee-light.jar
        cp loader/target/lucee-zero-${version}.jar $out/lucee-zero.jar
        cp loader/target/${version}.lco $out/lucee.lco
        runHook postInstall
      '';
    };

  flavors = {
    "" = {
      name = "lucee";
      file = "lucee.jar";
      description = "Lucee jar file without dependencies Lucee needs to run (built from source)";
    };
    "-light" = {
      name = "lucee-light";
      file = "lucee-light.jar";
      description = "Lucee Jar file without any Extensions bundled, \"Lucee light\" (built from source)";
    };
    "-zero" = {
      name = "lucee-zero";
      file = "lucee-zero.jar";
      description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\" (built from source)";
    };
  };

  mkFlavor =
    { build, flavor, version, javaVersion, tomcatPackage }:
    pkgs.stdenv.mkDerivation {
      inherit (flavor) name description;
      inherit version;
      passthru = { inherit tomcatPackage javaVersion build; };
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out
        ln -s ${build}/${flavor.file} $out/lucee.jar
      '';
    };

  mkJarsFor =
    defName: def:
    let
      build = mkLuceeSourceBuild def;
    in
    lib.mapAttrs'
      (suffix: flavor:
      lib.nameValuePair "${defName}${suffix}" (mkFlavor {
        inherit build flavor;
        inherit (def) version javaVersion;
        tomcatPackage = pkgs.tomcat11;
      }))
      flavors;

  versionedJars = lib.concatMapAttrs mkJarsFor definitions;

  # Friendly aliases -> the newest release of each line. lucee7 tracks what
  # https://download.lucee.org/ calls "Stable". Bumped by hand on updates.
  aliases = {
    lucee7 = "lucee7_1_0_204";
    lucee7_0 = "lucee7_0_5_41";
    lucee7_1 = "lucee7_1_0_204";
  };

  aliasJars = lib.concatMapAttrs
    (alias: target:
      lib.mapAttrs'
        (suffix: _: lib.nameValuePair "${alias}${suffix}" versionedJars."${target}${suffix}")
        flavors)
    aliases;

in
{
  jars = versionedJars // aliasJars;
}
