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

        # DMS reads the profile image from the AccountsService user icon, which
        # defaults to ~/.face (confirmed via busctl). So just put the avatar
        # there — no AccountsService plumbing needed.
        home.file.".face".source = ../../assets/avatar.png;

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
            # blur the wallpaper inside the overview. Two cooperating pieces:
            #  - blurWallpaperOnOverview: blurs the live wallpaper in the
            #    workspace tiles (internal MultiEffect, gated on inOverview).
            #  - blurredWallpaperLayer: draws a blurred wallpaper duplicate on the
            #    dms:blurwallpaper background layer, which the niri layer-rule
            #    below pins into the overview backdrop (place-within-backdrop). So
            #    the blurred copy only shows in the overview, not on the desktop.
            blurWallpaperOnOverview = true;
            blurredWallpaperLayer = true;
            # blur only shows through transparent pixels: stylix.opacity defaults
            # to fully opaque, so force the shell surfaces translucent enough to
            # see the blur. (mkForce overrides the stylix opacity target.)
            popupTransparency = lib.mkForce 0.82;
            dockTransparency = lib.mkForce 0.82;

            use24HourClock = true;
            showDock = false;
            # let stylix own GTK/Qt app theming; DMS shouldn't apply its own.
            gtkThemingEnabled = false;
            qtThemingEnabled = false;

            animationSpeed = 2;

            showWorkspaceIndex = true;
            showOccupiedWorkspacesOnly = true;

            osdMediaPlaybackEnabled = true;

            launcherLogoMode = "os";

            dankLauncherV2ShowFooter = false;
            dankLauncherV2UnloadOnClose = true;

            clipboardEnterToPaste = true;

            lockScreenShowPowerActions = false;

            lockBeforeSuspend = true;

            powerMenuActions = [ "logout" "reboot" "suspend" "hibernate" "poweroff" "lock" "restart" ];
            powerMenuDefaultAction = "poweroff";

            # custom bar layout (configVersion 5 barConfigs).
            barConfigs = [
              {
                id = "default";
                name = "Main Bar";
                enabled = true;
                position = 0;
                screenPreferences = [ "all" ];
                showOnLastDisplay = true;
                leftWidgets = [
                  "launcherButton"
                  "workspaceSwitcher"
                  {
                    id = "focusedWindow";
                    enabled = true;
                    focusedWindowCompactMode = false;
                  }
                ];
                centerWidgets = [
                  "music"
                  "clock"
                  "weather"
                ];
                rightWidgets = [
                  { id = "systemTray"; enabled = true; }
                  { id = "clipboard"; enabled = true; }
                  { id = "memUsage"; enabled = true; }
                  {
                    id = "diskUsage";
                    enabled = true;
                    mountPath = "/";
                  }
                  { id = "notificationButton"; enabled = true; }
                  { id = "battery"; enabled = true; }
                  {
                    id = "controlCenterButton";
                    enabled = true;
                    showAudioPercent = false;
                    showBrightnessIcon = false;
                    showBrightnessPercent = false;
                    showMicIcon = false;
                  }
                ];
                spacing = 8;
                innerPadding = 2;
                bottomGap = 0;
                transparency = 0.7;
                widgetTransparency = 0.7;
                squareCorners = false;
                noBackground = false;
                gothCornersEnabled = false;
                borderEnabled = false;
                fontScale = 1;
                autoHide = false;
                autoHideDelay = 250;
                openOnOverview = false;
                visible = true;
                popupGapsAuto = true;
                popupGapsManual = 4;
              }
            ];

            # control center quick-toggle widgets.
            controlCenterWidgets = [
              { id = "volumeSlider"; enabled = true; width = 50; }
              { id = "brightnessSlider"; enabled = true; width = 50; }
              { id = "wifi"; enabled = true; width = 50; }
              { id = "bluetooth"; enabled = true; width = 50; }
              { id = "audioOutput"; enabled = true; width = 50; }
              { id = "audioInput"; enabled = true; width = 50; }
              { id = "idleInhibitor"; enabled = true; width = 50; }
              { id = "nightMode"; enabled = true; width = 50; }
            ];
          };

          # session.json — night mode (auto, IP-located). stylix sets the
          # wallpaper keys here too; these merge with those.
          session = {
            weatherLocation = "Eeklo, 9900";
            weatherCoordinates = "51.2,3.6";

            nightModeEnabled = true;
            nightModeAutoEnabled = true;
            nightModeAutoMode = "location";
            nightModeUseIPLocation = true;
            nightModeTemperature = 5000;
            nightModeHighTemperature = 6500;
          };
        };

        # DMS honours DMS_DISABLE_MATUGEN to skip generating app theme templates
        # entirely; merges with the environment block in niri/layout.nix.
        programs.niri.settings.environment.DMS_DISABLE_MATUGEN = "1";

        # Pin DMS's blurred-wallpaper duplicate into niri's overview backdrop, so
        # it's only visible in the overview / between workspaces (never on the
        # normal desktop). This is the "manual niri configuration" that the
        # blurredWallpaperLayer setting requires. The layer is a Background
        # surface that ignores exclusive zones, which is what place-within-backdrop
        # needs.
        programs.niri.settings.layer-rules = [
          {
            matches = [ { namespace = "^dms:blurwallpaper$"; } ];
            place-within-backdrop = true;
          }
        ];
      };
  };
}
