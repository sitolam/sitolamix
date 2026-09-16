{ config, lib, ... }:
let
  cfg = config.apps.zed;
in
{
  options.apps.zed.enable = lib.mkEnableOption "Zed editor";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        programs.zed-editor = {
          enable = true;
          package = pkgs.zed-editor;
          userSettings = {
            vim_mode = true;
            # DMS renders ~/.config/zed/themes/dank-zed-theme.json from the wallpaper.
            theme = "DankShell Dark";
            buffer_font_family = "MesloLGS Nerd Font Mono";
            buffer_font_size = 20;
            ui_font_family = "DejaVu Sans";
            ui_font_size = 16;
          };
        };
      };
  };
}
