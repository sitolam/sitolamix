{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.dux-shell.enable {
    # General shell settings + bar layout/control-center widgets; merges
    # with the theme/blur settings in ./theme.nix.
    home.extraOptions.programs.dank-material-shell.settings = {
      # Written in this schema version, so DMS runs no migrations on a file
      # it can't write back (settings.json is a store symlink). Bump it with
      # the settings when a release moves keys; diff against what DMS's own
      # SettingsStore.migrateToVersion produces.
      configVersion = 42;

      clockFormat = "24h"; # "auto" follows the locale

      animationDuration = 500; # ms; DMS's "normal" preset

      # batteryNotifyLow: matches DMS core Settings > Battery > Alerts.
      batteryNotifyLow = true;
      # Switches power-profiles-daemon to power-saver at low battery.
      batteryAutoPowerSaver = true;

      launcherStyle = "spotlight"; # compact style, not the "full" app-drawer grid
      # Enter on an app that's already open focuses its window instead of
      # launching a second instance.
      launcherEnterAction = "focus";

      osdMediaPlaybackEnabled = true;
      # Bluetooth headset buttons (AVRCP) drive DMS's active media player.
      bluetoothMprisEnabled = true;
      # Animated Apple Music covers in the dash's media tab, where a track
      # has one.
      dashOptions.media.animatedArt = true;

      # Screen time per app in Dash > Digital Wellbeing. Tracking only:
      # limits would have to live here, the UI can't write settings.json.
      wellbeingEnabled = true;

      # DMS fills every unset dock key from its defaults. Smart auto-hide
      # hides it only while a window overlaps it.
      dockConfigs = [
        {
          id = "dock";
          name = "Dock";
          enabled = true;
          smartAutoHide = true;
        }
      ];

      dankLauncherV2ShowFooter = false;
      dankLauncherV2UnloadOnClose = true;

      clipboardEnterToPaste = true;

      # DMS records here that it already added its "DMS windows float" niri
      # rule; unset, it re-seeds and tries to write settings.json every start.
      dmsWindowsFloatingSeeded = [ "niri" ];

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
            {
              id = "launcherButton";
              enabled = true;
              launcherLogoMode = "os";
            }
            {
              id = "workspaceSwitcher";
              enabled = true;
              showWorkspaceIndex = false;
              showOccupiedWorkspacesOnly = true;
            }
            {
              id = "focusedWindow";
              enabled = true;
              focusedWindowCompactMode = false;
            }
          ];
          centerWidgets = [
            "music"
            {
              id = "clock";
              enabled = true;
              clockCompactMode = true;
              clockNotificationBadge = false;
            }
            "hoshiCalendar" # plugins.nix
            "weather"
          ];
          rightWidgets = [
            # Kept out of the bar itself: the section's overflow menu (one
            # button, opens a panel) holds them.
            {
              id = "ambientSound";
              enabled = true;
              overflowMode = "always";
            }
            {
              id = "systemTray";
              enabled = true;
              overflowMode = "always";
            }
            {
              id = "usbManager";
              enabled = true;
              overflowMode = "always";
            }
            # left click = popout, middle = start/stop, right = mute
            {
              id = "mouthGuard";
              enabled = true;
              overflowMode = "always";
            }
            {
              id = "dankKDEConnect";
              enabled = true;
            } # Dux Labs' own DankKDEConnect
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
          # Pre-2.0 look: bar and its widgets keep their own surface styling
          # instead of following the global interface style.
          followInterfaceStyle = false;
          widgetFollowInterfaceStyle = false;
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

      # control center grid: header tiles, then quick toggles. w/h count
      # grid cells (8 columns; w = 4 is half width).
      controlCenterWidgets = [
        {
          id = "user";
          enabled = true;
          w = 5;
          h = 1;
        }
      ]
      ++
        map
          (id: {
            inherit id;
            enabled = true;
            small = true;
            w = 1;
            h = 1;
          })
          [
            "settings"
            "lock"
            "power"
          ]
      ++ [
        {
          id = "volumeSlider";
          enabled = true;
          w = 4;
          h = 1;
        }
        {
          id = "brightnessSlider";
          enabled = true;
          w = 4;
          h = 1;
        }
        {
          id = "wifi";
          enabled = true;
          w = 4;
          h = 1;
        }
        {
          id = "bluetooth";
          enabled = true;
          w = 4;
          h = 1;
        }
        # tunnel is modules/services/wireguard-laxoi.nix; this just needs
        # NetworkManager (already on) plus a VPN-type connection to show.
        {
          id = "builtin_vpn";
          enabled = true;
          w = 4;
          h = 1;
        }
        {
          id = "audioOutput";
          enabled = true;
          w = 4;
          h = 1;
        }
        {
          id = "audioInput";
          enabled = true;
          w = 4;
          h = 1;
        }
        {
          id = "idleInhibitor";
          enabled = true;
          w = 4;
          h = 1;
        }
        {
          id = "nightMode";
          enabled = true;
          w = 4;
          h = 1;
        }
        # battery tile's detail view is DMS's native power-profile switcher
        # (power-profiles-daemon, ./default.nix); no standalone CC widget for it.
        {
          id = "battery";
          enabled = true;
          w = 4;
          h = 1;
        }
        # plugin toggles (id = "plugin_<pluginId>")
        {
          id = "plugin_niriDS";
          enabled = true;
          w = 4;
          h = 1;
        }
        {
          id = "edit";
          enabled = true;
          small = true;
          w = 1;
          h = 1;
        }
        {
          id = "runningApps";
          enabled = true;
          small = true;
          col = 0;
          row = 7;
          w = 4;
          h = 1;
        }
      ];
    };
  };
}
