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
              # DMS's own surfaces (bar, popouts, panels) get their blur from DMS
              # itself over the ext-background-effect protocol (niri supports it —
              # the BlurService log confirms), blurring only the card region, not
              # the whole full-screen surface. So we do NOT enable blur here (that
              # would frost the whole screen). We only set xray=false so the blur
              # samples the actual windows *behind* each surface (blurred), not
              # just the wallpaper — matching the window blur above. Protocol
              # surfaces don't inherit niri's default xray, hence this rule. A
              # background-effect with no `blur true` doesn't turn blur on, so
              # this stays card-only. blurwallpaper is excluded (no protocol blur;
              # handled by its own place-within-backdrop rule). Blur only *shows*
              # where surfaces are translucent — see the lowered opacity in
              # dms/theme.nix and dms/bar.nix.
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
