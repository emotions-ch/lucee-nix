# Lucee Definitions - Auto-generated
# Generated at: 2026-05-09 00:25:29 UTC
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
    version = "7.0.3.43";
    sha256 = "sha256-DQ8USIzieeVwIkw6ud4pcNcupG+Wk4+DpNAbLFZCvOE=";
    javaVersion = 25;
  };

  lucee7 = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "7.0.3.43";
    sha256 = "sha256-55FO6hLPGHjqDB0JBhWYQ1tls3Cb+bHz8p1dVA9kiXo=";
    javaVersion = 25;
  };

  lucee7-light = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "7.0.3.43";
    sha256 = "sha256-WbWWz5VGnrf1dPSf8XU0/ktzdpp+rf+ZWv7MmNSN8pQ=";
    javaVersion = 25;
  };


  lucee6-zero = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "6.2.6.19";
    sha256 = "sha256-GbFTGm/vPMLzghRD3VKUckUBVR5/AuuxX++LSS1xoOM=";
    javaVersion = 25;
  };

  lucee6 = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "6.2.6.19";
    sha256 = "sha256-RfUAnTbFl1LX89zFRBjiz99GN5OJmRXOWpy6FQ5S/dI=";
    javaVersion = 25;
  };

  lucee6-light = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "6.2.6.19";
    sha256 = "sha256-ZHbpfayd5E8RyKmTQgXnbGuFNe3uVS1Lr1aZ3pbaEA4=";
    javaVersion = 25;
  };




}
