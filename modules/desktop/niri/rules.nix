{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.niri.enable {
    home.extraOptions.programs.niri.settings.window-rules = [
      {
        geometry-corner-radius = {
          top-left = 18.0;
          top-right = 18.0;
          bottom-right = 18.0;
          bottom-left = 18.0;
        };
        clip-to-geometry = true;
        # translucency on every window so the global blur (niri/appearance.nix)
        # is clearly visible everywhere.
        opacity = 0.8;
      }
      {
        # extra glassy for the apps we want frosted.
        matches = [
          { app-id = "^spotify$"; }
          { app-id = "^Spotify$"; }
          { app-id = "^helium$"; }
        ];
        opacity = 0.65;
      }
      {
        matches = [
          { app-id = "^zen$"; }
          { app-id = "^zen-browser$"; }
          { app-id = "^firefox$"; }
          { app-id = "^helium$"; }
        ];
        draw-border-with-background = false;
      }
      {
        matches = [
          { app-id = "^steam$"; }
          { app-id = "^Steam$"; }
          { app-id = "^com\\.heroicgameslauncher\\.hgl$"; }
          { app-id = "^net\\.lutris\\.Lutris$"; }
        ];
        variable-refresh-rate = true;
        opacity = 1.0; # never dim games
      }
      {
        matches = [
          {
            title = "^(Open|Save|Save As|Open File|Choose File|Select File|File Upload|Preferences|Settings)$";
          }
        ];
        open-floating = true;
        default-column-width.proportion = 0.5;
        default-window-height.fixed = 720;
      }
    ];
  };
}
