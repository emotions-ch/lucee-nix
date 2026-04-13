# Lucee Definitions - Auto-generated
# Generated at: 2026-04-13 00:17:08 UTC
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
    sha256 = "sha256-3V7CI7DbysHrevdWbQa2z7SvzZ/W2Zq21R4rBVSz0Io=";
    javaVersion = 25;
  };

  lucee7 = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "7.0.3.43";
    sha256 = "sha256-RlCyGYCnL5COX/Nm0ZcEEWNhK5c/ywT+ITE8PG9Pq6U=";
    javaVersion = 25;
  };

  lucee7-light = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "7.0.3.43";
    sha256 = "sha256-iQQ1xLvjMxR21c13+ySs04q/2VtMw5s+wDPwqqEWkr0=";
    javaVersion = 25;
  };


  lucee6-zero = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "6.2.6.19";
    sha256 = "sha256-oEs1oWtoAetjQzQ02/D9tuSY7SFUJpsrNS3Vb3uvw5c=";
    javaVersion = 25;
  };

  lucee6 = mkLuceeVersion {
    name = "lucee";
    description = "Lucee jar file without dependencies Lucee needs to run";
    version = "6.2.6.19";
    sha256 = "sha256-/q5GF00aZnN5J6W4DvnFsvwd+uLDWICY+KYtZdv93UY=";
    javaVersion = 25;
  };

  lucee6-light = mkLuceeVersion {
    name = "lucee-light";
    description = "Lucee Jar file without any Extensions bundled, \"Lucee light\"";
    version = "6.2.6.19";
    sha256 = "sha256-zdGU5JzvJsGCrq7uOLOcdjkp6h8RDfvnW6u+ipEjqR0=";
    javaVersion = 25;
  };




}
