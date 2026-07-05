{ config, lib, ... }:
let
  cfg = config.apps.starship;
in
{
  options.apps.starship.enable = lib.mkEnableOption "starship prompt";

  config = lib.mkIf cfg.enable {
    home.extraOptions.programs.starship = {
      enable = true;
      enableFishIntegration = true;

      # Prompt is the upstream config (github.com/1amSimp1e/dots) with its
      # hardcoded hex swapped for stylix base16 palette names. stylix's starship
      # target sets `palette = "base16"` + defines `palettes.base16`, and merges
      # with these settings — so the prompt colours follow the active scheme.
      # Reading it straight from TOML keeps every Nerd Font glyph byte-exact.
      settings = builtins.fromTOML (builtins.readFile ./starship.toml);
    };
  };
}
