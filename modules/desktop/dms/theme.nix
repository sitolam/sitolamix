{ config, lib, ... }:
let
  # the active theme in ./themes. Its `dms` attr maps DankMaterialShell M3
  # tokens -> base16 slot names (null => let stylix's auto mapping stand); we
  # resolve those slots against the live scheme below so the shell palette comes
  # straight out of the stylix base16 colors. See themes/<name>.nix.
  theme = (import ../../../themes { inherit lib; }).get config.theming.stylix.theme;
in
{
  config = lib.mkIf config.desktop.dms.enable {
    home.extraOptions =
      { config, lib, pkgs, ... }:
      let
        # resolve the theme's M3-token -> base16-slot map into actual hex from
        # the active stylix scheme (config.lib.stylix.colors), then hand DMS a
        # custom theme file built from those base16 colors.
        c = config.lib.stylix.colors.withHashtag;
        palette = theme.dms or null;
        dmsThemeFile =
          if palette == null then
            null
          else
            let
              variant = (builtins.mapAttrs (_token: slot: c.${slot}) palette) // {
                name = config.lib.stylix.colors.scheme-name;
              };
            in
            (pkgs.formats.json { }).generate "dms-${theme.themeName}-theme.json" {
              dark = variant;
              light = variant;
            };
      in
      {
        # NB: theme, fonts, wallpaper and base opacity are all set by stylix's
        # built-in `dank-material-shell` target (currentThemeName/customThemeFile
        # from the base16 scheme, session.wallpaperPath from stylix.image,
        # popup/dockTransparency from stylix.opacity). We only add blur here.
        programs.dank-material-shell.settings = {
          runUserMatugenTemplates = false;

          # override stylix's generated palette with the active theme's `dms`
          # table when it has one; otherwise stylix's customThemeFile stays.
          customThemeFile = lib.mkIf (dmsThemeFile != null) (lib.mkForce dmsThemeFile);

          # ---- blur (niri 26.04 ext-background-effect) ----
          # frosted-glass blur behind DMS surfaces (bar, popouts, modals).
          blurEnabled = true;
          blurForegroundLayers = true;
          # blur the wallpaper inside the overview. Two cooperating pieces:
          #  - blurWallpaperOnOverview: blurs the live wallpaper in the workspace
          #    tiles (internal MultiEffect, gated on inOverview).
          #  - blurredWallpaperLayer: draws a blurred wallpaper duplicate on the
          #    dms:blurwallpaper background layer, which the niri layer-rule (see
          #    niri.nix) pins into the overview backdrop (place-within-backdrop).
          blurWallpaperOnOverview = true;
          blurredWallpaperLayer = true;
          # blur only shows through transparent pixels (DMS: readableSurface =
          # withAlpha(surfaceContainer, popupTransparency) — so this is the
          # surface *alpha*, 1.0 = fully opaque). stylix.opacity defaults these to
          # fully opaque, which hides the ext-background-effect blur entirely, so
          # force them well below 1.0 — the lower the alpha, the more see-through
          # (more of the backdrop shows through the surface tint). 0.3 is glassy;
          # raise toward 0.5 for more solid/readable.
          popupTransparency = lib.mkForce 0.3;
          dockTransparency = lib.mkForce 0.3;
        };
      };
  };
}
