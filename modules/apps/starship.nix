{ config, lib, ... }:
let
  cfg = config.apps.starship;
in
{
  options.apps.starship.enable = lib.mkEnableOption "starship prompt";

  config = lib.mkIf cfg.enable {
    # default starship prompt; its colours are ANSI names, so it follows the
    # terminal palette ghostty takes from the wallpaper.
    home.extraOptions.programs.starship = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
