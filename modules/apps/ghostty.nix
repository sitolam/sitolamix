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
        # non-Mono Nerd Font as primary: the "Mono" variant squishes the wide
        # icons (folder/git) and rounded powerline separators the starship prompt
        # uses. mkForce because stylix's ghostty target otherwise puts the "Mono"
        # family first in the fallback list.
        font-family = lib.mkForce [
          "MesloLGS Nerd Font"
          "Noto Color Emoji"
        ];
        font-size = 13;
        window-padding-x = 14;
        window-padding-y = 14;
        confirm-close-surface = false;
      };
    };
  };
}
