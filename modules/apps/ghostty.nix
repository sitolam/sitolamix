{ config, lib, ... }:
let
  cfg = config.apps.ghostty;
in
{
  options.apps.ghostty.enable = lib.mkEnableOption "ghostty terminal";

  config = lib.mkIf cfg.enable {
    home.extraOptions.programs.ghostty = {
      enable = true;
      settings = {
        font-family = "MesloLGS Nerd Font Mono";
        font-size = 13;
        window-padding-x = 14;
        window-padding-y = 14;
        confirm-close-surface = false;
      };
    };
  };
}
