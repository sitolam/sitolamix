{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.dms.enable {
    # general shell settings + the bar layout and control-center widgets. These
    # merge with the theme/blur settings in ./theme.nix.
    home.extraOptions.programs.dank-material-shell.settings = {
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
            { id = "systemTray"; enabled = true; }
            { id = "usbManager"; enabled = true; }
            # ambientSound + simpleAudioControl + aiOverviewControl are folded
            # into this collapsible group button (see plugins.nix widgetGroup).
            { id = "widgetGroup:media"; enabled = true; }
            { id = "homeAssistantMonitor"; enabled = true; } # hyprland-only upstream
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
  };
}
