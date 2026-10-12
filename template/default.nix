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

      - MasaCMS itself comes from lucee-nix; `wwwroot/` only holds what you add or
        override (sites, themes, modules, config/settings.ini.cfm), overlaid on top
      - `git init && git add .` - flakes only see tracked files
      - put your database password in `<host>.secret` (see `cfConfig` in `flake.nix`)
      - `nix develop`, then `start-lucee`
      - `nix build .#dockerImage` for the production image
    '';
  };
}
