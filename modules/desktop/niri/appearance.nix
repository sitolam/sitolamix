{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (inputs.niri.lib.kdl) leaf plain;
in
{
  config = lib.mkIf config.desktop.niri.enable {
    # HM function — needs home-manager's `config` for stylix colors.
    home.extraOptions =
      { config, lib, ... }:
      {
        programs.niri = {
          config = lib.mkOptionDefault (
            lib.mkAfter [
              # Blur behind every window. Only visible where a window is
              # translucent (see the opacity window-rules in niri/rules.nix),
              # e.g. the terminal, spotify, helium. xray = false so the blur
              # samples the actual windows *behind* each window (blurred),
              # not just the wallpaper.
              (plain "window-rule" [
                (plain "background-effect" [
                  (leaf "blur" true)
                  (leaf "xray" false)
                  (leaf "noise" 0.05)
                  (leaf "saturation" 2.4)
                ])
              ])
              # stronger global blur (more passes + larger offset = heavier blur).
              (plain "blur" [
                (leaf "passes" 4)
                (leaf "offset" 7.0)
                (leaf "noise" 0.04)
                (leaf "saturation" 1.8)
              ])
            ]
          );

          settings = {
            prefer-no-csd = true;
            hotkey-overlay.skip-at-startup = true;
            cursor.hide-after-inactive-ms = 5000;

            layout.focus-ring = {
              enable = true;
              active.color = "#${config.lib.stylix.colors.base0E}";
              inactive.color = "#${config.lib.stylix.colors.base02}";
            };

            # Overview backdrop (visible between workspaces, and as the fallback
            # on any output where DMS's blurred-wallpaper backdrop doesn't render
            # — currently the non-focused monitor). Use the theme's base so it
            # reads as an intentional dark surface rather than a sharp wallpaper.
            overview.backdrop-color = "#${config.lib.stylix.colors.base00}";

            debug = {
              honor-xdg-activation-with-invalid-serial = [ ];
            };
          };
        };
      };
  };
}
