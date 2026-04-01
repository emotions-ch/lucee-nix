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
    version = "7.0.1.100";
    sha256 = "05xzrvjan5vpd4jzq54xp0nhiiwnk6ixn6xs45f4v2wscvkapvzd";
    javaVersion = 25;
  };
}
