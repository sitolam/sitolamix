{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.desktop.dms;

  # the DankMaterialShell palette carried by the active theme in ./themes (null
  # => let stylix's auto base16->M3 mapping stand). See themes/<name>.nix.
  theme = (import ../../themes { inherit lib; }).get config.theming.stylix.theme;
  dmsThemeFile =
    if (theme.dms or null) == null then
      null
    else
      (pkgs.formats.json { }).generate "dms-${theme.themeName}-theme.json" {
        dark = theme.dms;
        light = theme.dms;
      };
in
{
  options.desktop.dms.enable = lib.mkEnableOption "DankMaterialShell (Quickshell bar + panels, blur)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { lib, pkgs, ... }:
      {
        imports = [ inputs.dms.homeModules.dank-material-shell ];

        programs.dank-material-shell = {
          enable = true;
          systemd.enable = true;

          # use the cached nixpkgs builds rather than the flake input building
          # dms-shell + quickshell from source. (dgop already defaults to pkgs.)
          package = pkgs.dms-shell;
          quickshell.package = pkgs.quickshell;

          # matugen would regenerate app color files from DMS's palette and fight
          # stylix; keep stylix authoritative for every app but DMS's own shell.
          enableDynamicTheming = false;

          # NB: theme, fonts, wallpaper and base opacity are all set by stylix's
          # built-in `dank-material-shell` target (currentThemeName/customThemeFile
          # from the base16 scheme, session.wallpaperPath from stylix.image,
          # popup/dockTransparency from stylix.opacity). We only add blur here.
          #
          # ~/.config/DankMaterialShell/settings.json (HM-managed => declarative).
          settings = {
            runUserMatugenTemplates = false;

            # override stylix's generated palette with the active theme's `dms`
            # table when it has one; otherwise stylix's customThemeFile stays.
            customThemeFile = lib.mkIf (dmsThemeFile != null) (lib.mkForce dmsThemeFile);

            # ---- blur (niri 26.04 ext-background-effect) ----
            blurEnabled = true;
            blurForegroundLayers = true;
            blurredWallpaperLayer = true;
            blurWallpaperOnOverview = true;
            # blur only shows through transparent pixels: stylix.opacity defaults
            # to fully opaque, so force the shell surfaces translucent enough to
            # see the blur. (mkForce overrides the stylix opacity target.)
            popupTransparency = lib.mkForce 0.82;
            dockTransparency = lib.mkForce 0.82;
          };
        };

        # DMS honours DMS_DISABLE_MATUGEN to skip generating app theme templates
        # entirely; merges with the environment block in niri/layout.nix.
        programs.niri.settings.environment.DMS_DISABLE_MATUGEN = "1";
      };
  };
}
