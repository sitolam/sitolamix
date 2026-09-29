{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.apps.ghostty;
in
{
  options.apps.ghostty.enable = lib.mkEnableOption "ghostty terminal";

  config = lib.mkIf cfg.enable {
    # Unpatched Meslo: ghostty 1.2+ stretches a pre-patched font's wide
    # powerline glyphs across cells (glitched the starship pills). Other apps
    # use the patched nerd font from modules/system/fonts.nix.
    fonts.packages = [ pkgs.meslo-lg ];

    home.extraOptions.programs.ghostty = {
      enable = true;
      settings = {
        # DMS renders the wallpaper palette to ~/.config/ghostty/themes/dankcolors
        # and reloads ghostty; starship, tmux, yazi, btop, bat, fzf and lazygit
        # all draw from this ANSI palette too.
        theme = "dankcolors";
        background-opacity = 0.8;
        font-family = [
          "Meslo LG S"
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
