{
  mkLuceeVersion,
  mkLuceeWithTomcat11,
  mkLuceeWithTomcat10,
  mkLuceeWithTomcat9,
}:

{
  lucee7-zero = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "7.0.2.106";
    sha256 = "sha256-gaLRqHFtZGdXdBYTzT4pzVEoFbAu2jmu/+fZeBllTXw=";
    javaVersion = 25;
  };

  lucee7_1-BETA-zero = mkLuceeVersion {
    name = "lucee-zero";
    description = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \"Lucee zero\"";
    version = "7.1.0.71-BETA";
    sha256 = "sha256-nUHYevX4vksWYaZWofycuGBwe8rGur4VSmGzzR5oPTA=";
    javaVersion = 25;
  };
}
