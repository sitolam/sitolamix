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
              # noctalia.kdl no longer written (we removed niri from noctalia builtin_ids);
              # focus-ring colors are set directly via stylix in settings below.
              (plain "window-rule" [
                (plain "background-effect" [
                  (leaf "blur" true)
                  (leaf "xray" true)
                  (leaf "noise" 0.05)
                  (leaf "saturation" 2.4)
                ])
              ])
              (plain "layer-rule" [
                (leaf "match" { namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel)$"; })
                (plain "background-effect" [
                  (leaf "blur" true)
                  (leaf "xray" false)
                  (leaf "noise" 0.05)
                  (leaf "saturation" 2.6)
                ])
              ])
              (plain "layer-rule" [
                (leaf "match" { namespace = "^noctalia-backdrop"; })
                (leaf "place-within-backdrop" true)
              ])
              (plain "layer-rule" [
                (leaf "match" { namespace = "^(fuzzel|waybar|wofi|swaync)$"; })
                (plain "background-effect" [
                  (leaf "blur" true)
                  (leaf "noise" 0.04)
                ])
              ])
              (plain "blur" [
                (leaf "passes" 3)
                (leaf "offset" 5.0)
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
