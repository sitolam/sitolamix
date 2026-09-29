{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.dms.enable {
    # General shell settings + bar layout/control-center widgets; merges
    # with the theme/blur settings in ./theme.nix.
    home.extraOptions.programs.dank-material-shell.settings = {
      use24HourClock = true;
      showDock = false;
      # DMS recolours GTK and Qt apps from the wallpaper; see matugen.nix.
      gtkThemingEnabled = true;
      qtThemingEnabled = true;

      animationSpeed = 2;
      animationVariant = 1; # Fluent (SettingsData.AnimationVariant: 0=Material, 1=Fluent, 2=Dynamic)

      # batteryNotifyLow: matches DMS core Settings > Battery > Alerts.
      batteryNotifyLow = true;

      launcherStyle = "spotlight"; # compact style, not the "full" app-drawer grid

      showWorkspaceIndex = false;
      showOccupiedWorkspacesOnly = true;

      osdMediaPlaybackEnabled = true;

      launcherLogoMode = "os";

      dankLauncherV2ShowFooter = false;
      dankLauncherV2UnloadOnClose = true;

      clipboardEnterToPaste = true;

      lockScreenShowPowerActions = false;

      lockBeforeSuspend = true;

      powerMenuActions = [
        "logout"
        "reboot"
        "suspend"
        "hibernate"
        "poweroff"
        "lock"
        "restart"
      ];
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
            # barDropdown drops ambientSound, systemTray, usbManager and
            # mouthGuard below the bar; those members stay off this list.
            {
              id = "barDropdown";
              enabled = true;
            }
            {
              id = "dankKDEConnect";
              enabled = true;
            } # AvengeMedia DankKDEConnect
            {
              id = "homeAssistantMonitor";
              enabled = true;
            } # hyprland-only upstream
            {
              id = "claudeCodeUsage";
              enabled = true;
            } # moved out of hidden bar, next to HA
            # unified cpu/ram/disk gauges (systemMonitorPlus, config in plugins.nix)
            {
              id = "systemMonitorPlus";
              enabled = true;
            }
            # no notificationButton, to keep the bar uncluttered; power lives
            # only in the control center now.
            {
              id = "controlCenterButton";
              enabled = true;
              showAudioPercent = false;
              showBrightnessIcon = false;
              showBrightnessPercent = false;
              showMicIcon = false;
              showBatteryIcon = false; # batteryPlus widget (right) is the battery readout now
              showIdleInhibitorIcon = true;
            }
            # arcatva/dms-battery-plus (plugins.nix) — far right of the bar.
            {
              id = "batteryPlus";
              enabled = true;
            }
          ];
          spacing = 8;
          innerPadding = 2;
          bottomGap = 0;
          transparency = 0.7; # translucent so the ext-background-effect blur behind it shows

          widgetTransparency = 0.3;
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
          hoverPopouts = true; # reveal a popout on hover, not just click
          hoverPopoutDelay = 50; # ms before it opens (DMS default: 150)
        }
      ];

      # control center quick-toggle widgets.
      controlCenterWidgets = [
        {
          id = "volumeSlider";
          enabled = true;
          width = 50;
        }
        {
          id = "brightnessSlider";
          enabled = true;
          width = 50;
        }
        {
          id = "wifi";
          enabled = true;
          width = 50;
        }
        {
          id = "bluetooth";
          enabled = true;
          width = 50;
        }
        # tunnel is modules/services/wireguard-laxoi.nix; this just needs
        # NetworkManager (already on) plus a VPN-type connection to show.
        {
          id = "builtin_vpn";
          enabled = true;
          width = 50;
        }
        {
          id = "audioOutput";
          enabled = true;
          width = 50;
        }
        {
          id = "audioInput";
          enabled = true;
          width = 50;
        }
        {
          id = "idleInhibitor";
          enabled = true;
          width = 50;
        }
        {
          id = "nightMode";
          enabled = true;
          width = 50;
        }
        # battery tile's detail view is DMS's native power-profile switcher
        # (power-profiles-daemon, ./default.nix); no standalone CC widget for it.
        {
          id = "battery";
          enabled = true;
          width = 50;
        }
        # plugin toggles (id = "plugin_<pluginId>"); takeABreak omitted — its
        # pause toggle's cross-instance lookup is unreliable.
        {
          id = "plugin_niriDS";
          enabled = true;
          width = 50;
        }
      ];
    };
  };
}
