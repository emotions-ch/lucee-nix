# Lucee Definitions - Auto-generated
# Generated at: 2026-06-29 00:31:57 UTC
# DO NOT EDIT MANUALLY - Use lucee-updater tool

{
  mkLuceeVersion,
  mkLuceeWithTomcat11,
  mkLuceeWithTomcat10,
  mkLuceeWithTomcat9,
}:

{


  lucee7_1-BETA-zero = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "7.1.0.71-BETA";
    sha256 = "sha256-nUHYevX4vksWYaZWofycuGBwe8rGur4VSmGzzR5oPTA=";
    javaVersion = 25;
  };

  lucee7_1-BETA = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "7.1.0.71-BETA";
    sha256 = "sha256-XcJbUfaO+kG7t85q/02wAl4c1BX9rRgFuZVVTOko+fQ=";
    javaVersion = 25;
  };

  lucee7_1-BETA-light = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "7.1.0.71-BETA";
    sha256 = "sha256-nUQBuwrrKfDB6fruAKyWlxyE9w5H7xb3OFSKg7IRQ1A=";
    javaVersion = 25;
  };


  lucee7-zero = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "7.0.4.34";
    sha256 = "sha256-EgIAzyjWlAwZz7+rdBk3naS3/+QLUzSGClOaagy+8bc=";
    javaVersion = 25;
  };

  lucee7 = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "7.0.4.34";
    sha256 = "sha256-pFM/Ilt1+lFDAYD+oiugv2Vzx/py7QiwusFleM6Z6Rc=";
    javaVersion = 25;
  };

  lucee7-light = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "7.0.4.34";
    sha256 = "sha256-eN6IWCkn8nmZamJe4YorTjIoIQUZT57j1YgXcIiLTcE=";
    javaVersion = 25;
  };


  lucee6-zero = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "6.2.7.16";
    sha256 = "sha256-GpWsX1fej49TuX29tZMUKqFLmDtfgXwLEM5Epzm/r9I=";
    javaVersion = 25;
  };

  lucee6 = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "6.2.7.16";
    sha256 = "sha256-l+5litC6tJJWr7b7pQKD3HG7mtDsZzNAAv29O7AE+2g=";
    javaVersion = 25;
  };

  lucee6-light = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "6.2.7.16";
    sha256 = "sha256-W2kPWzmrub48XGYiBA4+ukeNiCdjsI2vw5FVPQ6F0Ec=";
    javaVersion = 25;
  };




}
