{ self }:
{
  default = self.templates.lucee-default;

  lucee-default = {
    path = ./default;
    description = "a flake template for basic lucee project";
    welcomeText = ''
      # Lucee project

      - `git init && git add .` - flakes only see tracked files
      - put your database password in `localhost.secret`
      - `nix develop`, then `start-lucee`
      - `nix build .#dockerImage` for the production image
    '';
  };

  lucee-masa = {
    path = ./masa;
    description = "a flake template for basic MasaCMS in lucee";
    welcomeText = ''
      # MasaCMS project

      - copy the MasaCMS source into `wwwroot/`
      - `git init && git add .` - flakes only see tracked files
      - put your database password in `<host>.secret` (see `cfConfig` in `flake.nix`)
      - `nix develop`, then `start-lucee`
      - `nix build .#dockerImage` for the production image (needs the Masa source)
    '';
  };
}
