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
    # HM function.
    home.extraOptions =
      { lib, ... }:
      {
        programs.niri = {
          config = lib.mkOptionDefault (
            lib.mkAfter [
              # Blur behind every window, visible only where a window is
              # translucent (opacity window-rules in niri/rules.nix). xray =
              # false so the blur samples the windows behind, not just the
              # wallpaper.
              (plain "window-rule" [
                (plain "background-effect" [
                  (leaf "blur" true)
                  (leaf "xray" false)
                  (leaf "noise" 0.05)
                  (leaf "saturation" 2.4)
                ])
              ])
              # DMS's own surfaces (bar, popouts, panels) get their blur from
              # DMS itself over the ext-background-effect protocol, blurring
              # only the card region rather than the full surface. So no
              # `blur true` here (that would frost the whole screen) — only
              # xray=false, since protocol surfaces don't inherit niri's
              # default xray, to match the window blur above. blurwallpaper
              # is excluded (handled by its own place-within-backdrop rule).
              # Blur only shows where surfaces are translucent, via the
              # lowered opacity in dms/theme.nix and dms/bar.nix.
              (plain "layer-rule" [
                (leaf "match" { namespace = "^dms:"; })
                (leaf "exclude" { namespace = "blurwallpaper"; })
                (plain "background-effect" [
                  (leaf "xray" false)
                ])
              ])
              # global blur strength (more passes + larger offset = denser blur).
              (plain "blur" [
                (leaf "passes" 3)
                (leaf "offset" 6.0)
                (leaf "noise" 0.04)
                (leaf "saturation" 1.8)
              ])
            ]
          );

          settings = {
            prefer-no-csd = true;
            hotkey-overlay.skip-at-startup = true;
            cursor = {
              hide-after-inactive-ms = 5000;
              # niri draws its own compositor-side cursor from its own config,
              # not from the XCURSOR_THEME/XCURSOR_SIZE env vars that
              # home.pointerCursor sets, so it needs telling separately.
              # Pulled from theming.matugen's cursorTheme/cursorSize rather
              # than duplicated, so the two stay in sync.
              theme = config.theming.matugen.cursorTheme;
              size = config.theming.matugen.cursorSize;
            };

            layout.focus-ring = {
              enable = true;
              width = 3.0;
            };

            debug = {
              honor-xdg-activation-with-invalid-serial = [ ];
            };
          };
        };
      };
  };
}
