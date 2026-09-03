# Prebuilt CDN jar definitions ("-bin" outputs).
#
# Lucee >= 7 is built from source (see source.nix / source-definitions.nix);
# older versions - and prebuilt-only artifacts like BETA builds - are offered
# here as -bin attrs fetched from cdn.lucee.org. Hand-maintained; the hashes
# make any upstream change loud.

{ mkLuceeVersion }:

{

  lucee7_1-BETA-zero-bin = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "7.1.0.71-BETA";
    sha256 = "sha256-nUHYevX4vksWYaZWofycuGBwe8rGur4VSmGzzR5oPTA=";
    javaVersion = 25;
  };

  lucee7_1-BETA-bin = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "7.1.0.71-BETA";
    sha256 = "sha256-XcJbUfaO+kG7t85q/02wAl4c1BX9rRgFuZVVTOko+fQ=";
    javaVersion = 25;
  };

  lucee7_1-BETA-light-bin = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "7.1.0.71-BETA";
    sha256 = "sha256-nUQBuwrrKfDB6fruAKyWlxyE9w5H7xb3OFSKg7IRQ1A=";
    javaVersion = 25;
  };

  # 7.0.0.x still uses the old UUID-based Require-Extension format, which the
  # source build's cache seeding does not support - prebuilt only.
  lucee7_0_0_395-zero-bin = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "7.0.0.395";
    sha256 = "sha256-v+OYTPXHhZDEFTSpybfvPszAnwl1N6/LcOGx1P0IeSw=";
    javaVersion = 25;
  };

  lucee7_0_0_395-bin = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "7.0.0.395";
    sha256 = "sha256-H5S1nWj0sRSXiuwBacKNb+6gN7JQ7njjZMjPh+c90wE=";
    javaVersion = 25;
  };

  lucee7_0_0_395-light-bin = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "7.0.0.395";
    sha256 = "sha256-wEdsL17IjLY2Jb3B5HWw/jWCuhgp/2Z981dQVkgfD8Q=";
    javaVersion = 25;
  };

  lucee7_0_0_202-zero-bin = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "7.0.0.202";
    sha256 = "sha256-JNvEb1aOx2tLH3rDaARRr8CoFKntFvHUFz2GNKhhkHY=";
    javaVersion = 25;
  };

  lucee7_0_0_202-bin = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "7.0.0.202";
    sha256 = "sha256-z9B7z3ZmElgLRYfKXvZakRE2Jwv/LXM64qSsz8jfs6A=";
    javaVersion = 25;
  };

  lucee7_0_0_202-light-bin = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "7.0.0.202";
    sha256 = "sha256-TbSuzwKvmu6MkciX4DeuygrUAnfNZuAFLr3qrR5tgpk=";
    javaVersion = 25;
  };

  lucee6-zero-bin = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "6.2.7.16";
    sha256 = "sha256-GpWsX1fej49TuX29tZMUKqFLmDtfgXwLEM5Epzm/r9I=";
    javaVersion = 25;
  };

  lucee6-bin = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "6.2.7.16";
    sha256 = "sha256-l+5litC6tJJWr7b7pQKD3HG7mtDsZzNAAv29O7AE+2g=";
    javaVersion = 25;
  };

  lucee6-light-bin = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "6.2.7.16";
    sha256 = "sha256-W2kPWzmrub48XGYiBA4+ukeNiCdjsI2vw5FVPQ6F0Ec=";
    javaVersion = 25;
  };

}
