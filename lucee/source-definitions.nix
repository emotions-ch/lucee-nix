# Source build pins - maintained with tools/update-lucee.sh (see doc/updating.md)
#
# rev is the release commit: usually the head of the RELEASE BRANCH (e.g.
# refs/heads/7.0.4), NOT the release tag - tags point at commits whose pom
# still says X.Y.Z.P-SNAPSHOT. When the branch has moved past the release
# (7.1.0.204) the exact commit is pinned instead.
#
# cacheEntries pre-seed Lucee's ant download cache (${rootDir}/cache/):
# the .lex extensions from Require-Extension in the core MANIFEST.MF,
# testbox, and the "stable loader" jar. File names must match what
# ant/build-extensions.xml expects: <group>-<artifact>-<version>.lex
#
# Versions up to 7.0.0.x use the old UUID-based Require-Extension format and
# cannot be built this way; they are offered as -bin jars in definitions.nix.
{

  lucee7_0_1_100 = {
    version = "7.0.1.100";
    rev = "7ebb5388a0e898d4ed02dc165ebb7dd49e6c0bd9";
    srcHash = "sha256-oMgjlLFBqp/2tQhio6LUnNj6i5dS7YFPPCZa/yI2Sf0=";
    mvnDepsHash = "sha256-97Xn0EnUgTfAEj79AY7+n3GRrl4UBDVKh0uKjZ21TZo=";
    javaVersion = 25;
    cacheEntries =
      let
        mvn = "https://repo1.maven.org/maven2/org/lucee";
        cdn = "https://cdn.lucee.org/org/lucee";
        lex = base: artifact: version: hash: {
          name = "org.lucee-${artifact}-${version}.lex";
          url = "${base}/${artifact}/${version}/${artifact}-${version}.lex";
          inherit hash;
        };
      in
      [
        (lex mvn "mysql-jdbc-extension" "9.5.0" "sha256-dWT8bwUk1Fj8NWOXfag/YLwYFKYVy6h+RETD4U+vsXU=")
        (lex mvn "mssql-jdbc-extension" "13.2.1" "sha256-j6RP40UBVE9EGUOEr2A0eWCzjwAVkdxSfjZrauVBQRQ=")
        (lex mvn "postgresql-jdbc-extension" "42.7.7" "sha256-CBnRdgty0zwh2k3gkPvizvbTSRaIPzr19kso1JvAaYk=")
        (lex cdn "jtds-jdbc-extension" "1.3.1" "sha256-XPsEjpvcGQXE9Gv77Lus9fRn8MfJbxmeABaqaN9u2Cw=")
        (lex mvn "administrator-extension" "1.0.0.6" "sha256-kwMDUUdwkwM+f5zxndDIo1DKCM3RRF5ZbHacRBR94wU=")
        (lex mvn "documentation-extension" "1.0.0.5" "sha256-r7jS4oxgdq9MRwc9xzbWSPgLi/tUWoGWOhIm0iFeBC0=")
        (lex mvn "s3-extension" "2.0.3.0" "sha256-2lEJ1Xey/HI+5DC4nzmTxc85lX/Q9AG8daF9SWxU0S0=")
        (lex mvn "pdf-extension" "2.0.0.1" "sha256-lsGuvywDLLbFsJnDG3Z8BO3XXOPB9F8N0nmSCGqxLTY=")
        (lex mvn "image-extension" "3.0.0.6" "sha256-m2w5aM93MBw8hX5j+AZGsexmaiONbyU0CcnigjTXpz4=")
        (lex mvn "esapi-extension" "2.6.0.1" "sha256-RKJjN0kEdDDcVPBryqnt+aVBmj76durJcEFdeH20rqM=")
        (lex mvn "scheduler-classic-extension" "1.0.0.0" "sha256-upuO/ZasSVsJkgqjkFsp+Xu6YUOlyUvRMfh5VKw8Gt4=")
        (lex mvn "compress-extension" "2.0.0.3" "sha256-e5c4Hq4B74EH8alj1xDa6gXTJ1MptRo4aUT/S9wzSwE=")
        {
          name = "testbox-3.2.0.zip";
          url = "https://downloads.ortussolutions.com/ortussolutions/testbox/3.2.0/testbox-3.2.0.zip";
          hash = "sha256-VBEL9l4mPUAsWQJlCeGxOJpb3YXv82Yza9u/rqW0ihA=";
        }
        {
          name = "lucee-5.3.7.48.jar";
          url = "https://cdn.lucee.org/lucee-5.3.7.48.jar";
          hash = "sha256-w0oigFqXhHtNRDVcKVrT06YPWLjZQzxtrPhK3rWwV6w=";
        }
      ];
  };

  lucee7_0_2_106 = {
    version = "7.0.2.106";
    rev = "ed12711f10c6268a833e561de425d0a34d46f3fd";
    srcHash = "sha256-fB0mlWskPJx2BkjrXoTm+nIruAr3e3Dh5yj6GsYYk9k=";
    mvnDepsHash = "sha256-/ONlKUX2LmE/Dtt5pmd6u0PXe0H9sYhM67tDDbngZ5g=";
    javaVersion = 25;
    cacheEntries =
      let
        mvn = "https://repo1.maven.org/maven2/org/lucee";
        cdn = "https://cdn.lucee.org/org/lucee";
        lex = base: artifact: version: hash: {
          name = "org.lucee-${artifact}-${version}.lex";
          url = "${base}/${artifact}/${version}/${artifact}-${version}.lex";
          inherit hash;
        };
      in
      [
        (lex mvn "mysql-jdbc-extension" "9.5.0" "sha256-dWT8bwUk1Fj8NWOXfag/YLwYFKYVy6h+RETD4U+vsXU=")
        (lex mvn "mssql-jdbc-extension" "13.2.1" "sha256-j6RP40UBVE9EGUOEr2A0eWCzjwAVkdxSfjZrauVBQRQ=")
        (lex mvn "postgresql-jdbc-extension" "42.7.7" "sha256-CBnRdgty0zwh2k3gkPvizvbTSRaIPzr19kso1JvAaYk=")
        (lex cdn "jtds-jdbc-extension" "1.3.1" "sha256-XPsEjpvcGQXE9Gv77Lus9fRn8MfJbxmeABaqaN9u2Cw=")
        (lex mvn "administrator-extension" "1.0.0.6" "sha256-kwMDUUdwkwM+f5zxndDIo1DKCM3RRF5ZbHacRBR94wU=")
        (lex mvn "documentation-extension" "1.0.0.5" "sha256-r7jS4oxgdq9MRwc9xzbWSPgLi/tUWoGWOhIm0iFeBC0=")
        (lex mvn "s3-extension" "2.0.3.0" "sha256-2lEJ1Xey/HI+5DC4nzmTxc85lX/Q9AG8daF9SWxU0S0=")
        (lex cdn "pdf-extension" "2.0.1.0" "sha256-0TDI3FEDt81cYGmqILQiJGetMzT/ebhMcF5A+Lhr3N4=")
        (lex mvn "image-extension" "3.0.0.6" "sha256-m2w5aM93MBw8hX5j+AZGsexmaiONbyU0CcnigjTXpz4=")
        (lex mvn "esapi-extension" "3.0.0.14" "sha256-ADf/hjs2L5DgehKk8au1hgw0XNTyefA7o8HgIkBGogM=")
        (lex mvn "scheduler-classic-extension" "1.0.0.0" "sha256-upuO/ZasSVsJkgqjkFsp+Xu6YUOlyUvRMfh5VKw8Gt4=")
        (lex cdn "compress-extension" "2.1.0.2-SNAPSHOT" "sha256-zotdxpirhHc1/4Csv7nhcLGoruwxLBK1aLxCLT0NHsc=")
        {
          name = "testbox-3.2.0.zip";
          url = "https://downloads.ortussolutions.com/ortussolutions/testbox/3.2.0/testbox-3.2.0.zip";
          hash = "sha256-VBEL9l4mPUAsWQJlCeGxOJpb3YXv82Yza9u/rqW0ihA=";
        }
        {
          name = "lucee-5.3.7.48.jar";
          url = "https://cdn.lucee.org/lucee-5.3.7.48.jar";
          hash = "sha256-w0oigFqXhHtNRDVcKVrT06YPWLjZQzxtrPhK3rWwV6w=";
        }
      ];
  };

  lucee7_0_3_43 = {
    version = "7.0.3.43";
    rev = "009460f4c09480a3255a132b0b2215a5ff191250";
    srcHash = "sha256-5rtwILfLLIFXKGbcPaJXDal2HJvQpOm+w9uufIsBUN8=";
    mvnDepsHash = "sha256-Z0BXTBh4xCFwruRq4H1f4lCPotK637wi73VlEhwqbag=";
    javaVersion = 25;
    cacheEntries =
      let
        mvn = "https://repo1.maven.org/maven2/org/lucee";
        cdn = "https://cdn.lucee.org/org/lucee";
        lex = base: artifact: version: hash: {
          name = "org.lucee-${artifact}-${version}.lex";
          url = "${base}/${artifact}/${version}/${artifact}-${version}.lex";
          inherit hash;
        };
      in
      [
        (lex mvn "mysql-jdbc-extension" "9.5.0" "sha256-dWT8bwUk1Fj8NWOXfag/YLwYFKYVy6h+RETD4U+vsXU=")
        (lex mvn "mssql-jdbc-extension" "13.2.1" "sha256-j6RP40UBVE9EGUOEr2A0eWCzjwAVkdxSfjZrauVBQRQ=")
        (lex mvn "postgresql-jdbc-extension" "42.7.7" "sha256-CBnRdgty0zwh2k3gkPvizvbTSRaIPzr19kso1JvAaYk=")
        (lex cdn "jtds-jdbc-extension" "1.3.1" "sha256-XPsEjpvcGQXE9Gv77Lus9fRn8MfJbxmeABaqaN9u2Cw=")
        (lex mvn "administrator-extension" "1.0.0.6" "sha256-kwMDUUdwkwM+f5zxndDIo1DKCM3RRF5ZbHacRBR94wU=")
        (lex mvn "documentation-extension" "1.0.0.5" "sha256-r7jS4oxgdq9MRwc9xzbWSPgLi/tUWoGWOhIm0iFeBC0=")
        (lex mvn "s3-extension" "2.0.3.0" "sha256-2lEJ1Xey/HI+5DC4nzmTxc85lX/Q9AG8daF9SWxU0S0=")
        (lex cdn "pdf-extension" "2.0.0.3-SNAPSHOT" "sha256-cKHVzs8StGMSITCc8ooCzVNMWd7RWDF0JoiTP7M9qBw=")
        (lex mvn "image-extension" "3.0.0.6" "sha256-m2w5aM93MBw8hX5j+AZGsexmaiONbyU0CcnigjTXpz4=")
        (lex mvn "esapi-extension" "3.0.0.14-RC" "sha256-X/3LjbAOb1Gocumx3zJRnRw3TOyGQnBhXR4cIYPZUTI=")
        (lex mvn "scheduler-classic-extension" "1.0.0.0" "sha256-upuO/ZasSVsJkgqjkFsp+Xu6YUOlyUvRMfh5VKw8Gt4=")
        (lex cdn "compress-extension" "2.1.0.2-SNAPSHOT" "sha256-zotdxpirhHc1/4Csv7nhcLGoruwxLBK1aLxCLT0NHsc=")
        {
          name = "testbox-3.2.0.zip";
          url = "https://downloads.ortussolutions.com/ortussolutions/testbox/3.2.0/testbox-3.2.0.zip";
          hash = "sha256-VBEL9l4mPUAsWQJlCeGxOJpb3YXv82Yza9u/rqW0ihA=";
        }
        {
          name = "lucee-5.3.7.48.jar";
          url = "https://cdn.lucee.org/lucee-5.3.7.48.jar";
          hash = "sha256-w0oigFqXhHtNRDVcKVrT06YPWLjZQzxtrPhK3rWwV6w=";
        }
      ];
  };
  lucee7_0_4_34 = {
    version = "7.0.4.34";
    rev = "8bda3e9162a2e88763b5b0f15ab2b669be7313ac";
    srcHash = "sha256-nwjd27/bzrFwbN52jiM2ELsV2iHvR2Jm/FtHkUUNKVw=";
    mvnDepsHash = "sha256-1tojE0uFdK3zbCXSvohvMPEpVbuFjAwOoyM6qZ5sw84=";
    javaVersion = 25;
    cacheEntries =
      let
        mvn = "https://repo1.maven.org/maven2/org/lucee";
        cdn = "https://cdn.lucee.org/org/lucee";
        lex = base: artifact: version: hash: {
          name = "org.lucee-${artifact}-${version}.lex";
          url = "${base}/${artifact}/${version}/${artifact}-${version}.lex";
          inherit hash;
        };
      in
      [
        (lex mvn "mysql-jdbc-extension" "9.6.0" "sha256-Ih3DuP+jCfUyNf1LjiT/Gi0sBOOZ5ON4wavFFReUuR8=")
        (lex mvn "mssql-jdbc-extension" "13.2.1" "sha256-j6RP40UBVE9EGUOEr2A0eWCzjwAVkdxSfjZrauVBQRQ=")
        (lex mvn "postgresql-jdbc-extension" "42.7.9" "sha256-tLpKEQDLuHtEEb3sT1xQG37t16VMSKX//d6vtnHGQD8=")
        (lex cdn "jtds-jdbc-extension" "1.3.1" "sha256-XPsEjpvcGQXE9Gv77Lus9fRn8MfJbxmeABaqaN9u2Cw=")
        (lex mvn "administrator-extension" "1.0.0.7" "sha256-/sAER5PB6IBU/FQW48NrqylgSGnHnADzECejcbeK6Zg=")
        (lex mvn "documentation-extension" "1.0.0.6" "sha256-V8FRLmudDuaJ3YlicvHS6VQ0vD1NkAmbUF5I7kmz6Ww=")
        (lex mvn "s3-extension" "2.0.3.1" "sha256-6SnOn53FugffVLZ4fN94BdcLMVf21YZJgm54SDMLWNs=")
        (lex cdn "pdf-extension" "2.0.1.0" "sha256-0TDI3FEDt81cYGmqILQiJGetMzT/ebhMcF5A+Lhr3N4=")
        (lex mvn "image-extension" "3.0.1.1" "sha256-e8eHeUIjziJqg2LyREw+OlN5d+0hnkzEmNiAjwwJPWU=")
        (lex mvn "esapi-extension" "3.0.0.14" "sha256-ADf/hjs2L5DgehKk8au1hgw0XNTyefA7o8HgIkBGogM=")
        (lex mvn "scheduler-classic-extension" "1.0.0.1" "sha256-e2cwzDBdn7ENP4Q2ZLkIj3nRZEBt66ZTntiyU1GcPWU=")
        # SNAPSHOT: mutable upstream; a hash mismatch/404 here means it was
        # republished - re-pin with tools/update-lucee.sh
        (lex cdn "compress-extension" "2.1.0.2-SNAPSHOT" "sha256-zotdxpirhHc1/4Csv7nhcLGoruwxLBK1aLxCLT0NHsc=")
        {
          name = "testbox-3.2.0.zip";
          url = "https://downloads.ortussolutions.com/ortussolutions/testbox/3.2.0/testbox-3.2.0.zip";
          hash = "sha256-VBEL9l4mPUAsWQJlCeGxOJpb3YXv82Yza9u/rqW0ihA=";
        }
        {
          name = "lucee-5.3.7.48.jar";
          url = "https://cdn.lucee.org/lucee-5.3.7.48.jar";
          hash = "sha256-w0oigFqXhHtNRDVcKVrT06YPWLjZQzxtrPhK3rWwV6w=";
        }
      ];
  };


  lucee7_0_5_41 = {
    version = "7.0.5.41";
    rev = "60d3afff9a864a010d6c56bbf8040de6559b31ad";
    srcHash = "sha256-tnyqyIJNpVT4xbfnVdBCHEwJLx/P30BzshYSlHTErQE=";
    mvnDepsHash = "sha256-ty9XvsJxpsPOZ6MV2/tRfXRxBty5T2xDhkk86THp6eQ=";
    javaVersion = 25;
    cacheEntries =
      let
        mvn = "https://repo1.maven.org/maven2/org/lucee";
        cdn = "https://cdn.lucee.org/org/lucee";
        lex = base: artifact: version: hash: {
          name = "org.lucee-${artifact}-${version}.lex";
          url = "${base}/${artifact}/${version}/${artifact}-${version}.lex";
          inherit hash;
        };
      in
      [
        (lex mvn "mysql-jdbc-extension" "9.6.0" "sha256-Ih3DuP+jCfUyNf1LjiT/Gi0sBOOZ5ON4wavFFReUuR8=")
        (lex mvn "mssql-jdbc-extension" "13.2.1" "sha256-j6RP40UBVE9EGUOEr2A0eWCzjwAVkdxSfjZrauVBQRQ=")
        (lex mvn "postgresql-jdbc-extension" "42.7.9" "sha256-tLpKEQDLuHtEEb3sT1xQG37t16VMSKX//d6vtnHGQD8=")
        (lex cdn "jtds-jdbc-extension" "1.3.1" "sha256-XPsEjpvcGQXE9Gv77Lus9fRn8MfJbxmeABaqaN9u2Cw=")
        (lex mvn "administrator-extension" "1.0.0.7" "sha256-/sAER5PB6IBU/FQW48NrqylgSGnHnADzECejcbeK6Zg=")
        (lex mvn "documentation-extension" "1.0.0.6" "sha256-V8FRLmudDuaJ3YlicvHS6VQ0vD1NkAmbUF5I7kmz6Ww=")
        (lex mvn "s3-extension" "2.0.3.1" "sha256-6SnOn53FugffVLZ4fN94BdcLMVf21YZJgm54SDMLWNs=")
        (lex cdn "pdf-extension" "2.0.1.0" "sha256-0TDI3FEDt81cYGmqILQiJGetMzT/ebhMcF5A+Lhr3N4=")
        (lex mvn "image-extension" "3.0.1.1" "sha256-e8eHeUIjziJqg2LyREw+OlN5d+0hnkzEmNiAjwwJPWU=")
        (lex mvn "esapi-extension" "3.0.0.14" "sha256-ADf/hjs2L5DgehKk8au1hgw0XNTyefA7o8HgIkBGogM=")
        (lex mvn "scheduler-classic-extension" "1.0.0.1" "sha256-e2cwzDBdn7ENP4Q2ZLkIj3nRZEBt66ZTntiyU1GcPWU=")
        (lex cdn "compress-extension" "2.1.0.2-SNAPSHOT" "sha256-zotdxpirhHc1/4Csv7nhcLGoruwxLBK1aLxCLT0NHsc=")
        {
          name = "testbox-3.2.0.zip";
          url = "https://downloads.ortussolutions.com/ortussolutions/testbox/3.2.0/testbox-3.2.0.zip";
          hash = "sha256-VBEL9l4mPUAsWQJlCeGxOJpb3YXv82Yza9u/rqW0ihA=";
        }
        {
          name = "lucee-5.3.7.48.jar";
          url = "https://cdn.lucee.org/lucee-5.3.7.48.jar";
          hash = "sha256-w0oigFqXhHtNRDVcKVrT06YPWLjZQzxtrPhK3rWwV6w=";
        }
      ];
  };

  lucee7_1_0_204 = {
    version = "7.1.0.204";
    rev = "e4b8a7dadb7f7c3c44edec14d1e7e4c98d7e5981";
    srcHash = "sha256-BNHmNRxvi4TXhPkvlPjJp3k7N2zF+C0XnTI7Fz/Fd04=";
    mvnDepsHash = "sha256-0CWpIq/sYfPR4sqF4XXC4ugWPjGf9JyCwOsGMEBmDsw=";
    javaVersion = 25;
    cacheEntries =
      let
        mvn = "https://repo1.maven.org/maven2/org/lucee";
        cdn = "https://cdn.lucee.org/org/lucee";
        lex = base: artifact: version: hash: {
          name = "org.lucee-${artifact}-${version}.lex";
          url = "${base}/${artifact}/${version}/${artifact}-${version}.lex";
          inherit hash;
        };
      in
      [
        (lex mvn "mysql-jdbc-extension" "9.6.0" "sha256-Ih3DuP+jCfUyNf1LjiT/Gi0sBOOZ5ON4wavFFReUuR8=")
        (lex mvn "mssql-jdbc-extension" "13.2.1" "sha256-j6RP40UBVE9EGUOEr2A0eWCzjwAVkdxSfjZrauVBQRQ=")
        (lex mvn "postgresql-jdbc-extension" "42.7.9" "sha256-tLpKEQDLuHtEEb3sT1xQG37t16VMSKX//d6vtnHGQD8=")
        (lex mvn "administrator-extension" "1.0.0.7" "sha256-/sAER5PB6IBU/FQW48NrqylgSGnHnADzECejcbeK6Zg=")
        (lex mvn "documentation-extension" "1.0.0.6" "sha256-V8FRLmudDuaJ3YlicvHS6VQ0vD1NkAmbUF5I7kmz6Ww=")
        (lex mvn "s3-extension" "2.0.3.1" "sha256-6SnOn53FugffVLZ4fN94BdcLMVf21YZJgm54SDMLWNs=")
        (lex cdn "pdf-extension" "2.0.1.0" "sha256-0TDI3FEDt81cYGmqILQiJGetMzT/ebhMcF5A+Lhr3N4=")
        (lex mvn "image-extension" "3.0.0.9" "sha256-HfTOeY2RrvYA2PUs5xu8YADX+SvpCxApAUEFhKIt+Ec=")
        (lex mvn "esapi-extension" "3.0.0.14" "sha256-ADf/hjs2L5DgehKk8au1hgw0XNTyefA7o8HgIkBGogM=")
        (lex mvn "scheduler-classic-extension" "1.0.0.1" "sha256-e2cwzDBdn7ENP4Q2ZLkIj3nRZEBt66ZTntiyU1GcPWU=")
        (lex cdn "compress-extension" "2.1.0.2-SNAPSHOT" "sha256-zotdxpirhHc1/4Csv7nhcLGoruwxLBK1aLxCLT0NHsc=")
        (lex mvn "mail-extension" "1.1.0.6" "sha256-zNtmF/pHQfEDiW7seSGspKzMYtSqmYlXjalWRo3kpc4=")
        (lex mvn "ftp-extension" "1.0.0.5-RC" "sha256-cbsa6OMjgDO6/LxyQtyT4e1UF0M3N8z0W26fMYN9gVI=")
        {
          name = "testbox-3.2.0.zip";
          url = "https://downloads.ortussolutions.com/ortussolutions/testbox/3.2.0/testbox-3.2.0.zip";
          hash = "sha256-VBEL9l4mPUAsWQJlCeGxOJpb3YXv82Yza9u/rqW0ihA=";
        }
        {
          name = "lucee-5.3.7.48.jar";
          url = "https://cdn.lucee.org/lucee-5.3.7.48.jar";
          hash = "sha256-w0oigFqXhHtNRDVcKVrT06YPWLjZQzxtrPhK3rWwV6w=";
        }
      ];
  };

}
