{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.desktop.dms;
in
{
  options.desktop.dms.enable = lib.mkEnableOption "DankMaterialShell (Quickshell bar + panels, blur)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { config, lib, pkgs, ... }:
      let
        # Prefer a hand-tuned per-scheme DMS theme from ./assets/dms-themes,
        # keyed by the active stylix scheme slug (e.g. "catppuccin-mocha.json").
        # Stylix's auto-generated base16->M3 mapping leads with base0D (blue),
        # which makes cool schemes look Nord-ish; these files let us pick the
        # accent that actually reads as the scheme (mauve for mocha). When no
        # matching file exists, we fall through to stylix's generated theme, so
        # dropping in e.g. nord.json later is all it takes to cover a new scheme.
        schemeThemeFile = ../../assets/dms-themes + "/${config.lib.stylix.colors.slug}.json";
        hasSchemeTheme = builtins.pathExists schemeThemeFile;
      in
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

            # override stylix's generated palette with our per-scheme file when
            # one exists; otherwise stylix's customThemeFile stays in effect.
            customThemeFile = lib.mkIf hasSchemeTheme (lib.mkForce schemeThemeFile);

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
