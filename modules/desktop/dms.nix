{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.desktop.dms;

  # the active theme in ./themes. Its `dms` attr maps DankMaterialShell M3
  # tokens -> base16 slot names (null => let stylix's auto mapping stand); we
  # resolve those slots against the live scheme below so the shell palette comes
  # straight out of the stylix base16 colors. See themes/<name>.nix.
  theme = (import ../../themes { inherit lib; }).get config.theming.stylix.theme;
in
{
  options.desktop.dms.enable = lib.mkEnableOption "DankMaterialShell (Quickshell bar + panels, blur)";

  config = lib.mkIf cfg.enable {
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
        imports = [ inputs.dms.homeModules.dank-material-shell ];

        # DMS only reads its settings at startup, and the systemd user service's
        # unit doesn't change when only settings.json/the theme file change — so
        # nothing restarts it on rebuild. Trigger a restart (via sd-switch) when
        # the generated settings.json changes, so theme/blur edits take effect
        # after `nixos-rebuild switch` without a manual restart or relogin.
        systemd.user.services.dms.Unit.X-Restart-Triggers = [
          config.xdg.configFile."DankMaterialShell/settings.json".source
        ];

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
            # frosted-glass blur behind DMS surfaces (bar, popouts, modals).
            blurEnabled = true;
            blurForegroundLayers = true;
            # blur the wallpaper only while the niri overview is open (handled
            # internally, gated on NiriService.inOverview — no niri rule needed).
            blurWallpaperOnOverview = true;
            # NB: leave this off. It draws a *second, always-blurred* wallpaper
            # copy on the background layer (namespace dms:blurwallpaper) that only
            # makes sense with a manual niri layer-rule; on its own it just blurs
            # the whole desktop permanently.
            blurredWallpaperLayer = false;
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
