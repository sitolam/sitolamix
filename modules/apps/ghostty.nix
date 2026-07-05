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
    # 1.2+, which is what made the starship pills glitch. stylix still uses the
    # patched nerd font for other apps.
    fonts.packages = [ pkgs.meslo-lg ];

    home.extraOptions.programs.ghostty = {
      enable = true;
      settings = {
        # primary = unpatched Meslo; ghostty supplies the nerd/powerline glyphs.
        # mkForce because stylix's ghostty target sets the patched font here.
        font-family = lib.mkForce [
          "Meslo LG S"
          "Noto Color Emoji"
        ];
        font-size = lib.mkForce 13;
        window-padding-x = 14;
        window-padding-y = 14;
        confirm-close-surface = false;
      };
    };
  };
}
