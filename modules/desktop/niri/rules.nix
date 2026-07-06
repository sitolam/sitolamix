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
        # niri draws the focus ring/border as a solid rect *behind* the window;
        # on a translucent window that fills it with the (mauve) ring colour.
        # Draw it as a hollow ring instead so the blur shows, not the tint.
        draw-border-with-background = false;
      }
      {
        # extra glassy for the apps we want frosted.
        matches = [
          { app-id = "^spotify$"; }
          { app-id = "^Spotify$"; }
        ];
        opacity = 0.65;
      }
      {
        # browsers: a little less frosted than the 0.8 global.
        matches = [
          { app-id = "^helium$"; }
          { app-id = "^zen$"; }
          { app-id = "^zen-browser$"; }
        ];
        opacity = 0.85;
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
