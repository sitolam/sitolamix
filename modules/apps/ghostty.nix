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
    # unpatched Meslo so ghostty renders the Nerd Font glyphs with its own
    # built-in symbol font (scaled to the cell) instead of a pre-patched font's
    # wide powerline glyphs — the latter get stretched across cells in ghostty
    # 1.2+, which is what made the starship pills glitch. other apps use the
    # patched nerd font from modules/system/fonts.nix.
    fonts.packages = [ pkgs.meslo-lg ];

    home.extraOptions.programs.ghostty = {
      enable = true;
      settings = {
        # DMS renders the wallpaper palette to ~/.config/ghostty/themes/dankcolors
        # and signals ghostty to reload. starship, tmux, yazi, btop, bat, fzf and
        # lazygit all draw with this ANSI palette, so they follow too.
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
