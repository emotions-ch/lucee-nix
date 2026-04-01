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
}
