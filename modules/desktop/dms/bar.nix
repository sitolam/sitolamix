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
      # animation style (SettingsData.AnimationVariant): 0=Material, 1=Fluent,
      # 2=Dynamic.
      animationVariant = 1; # Fluent

      # default app launcher: compact Spotlight style rather than the "full"
      # app-drawer grid.
      launcherStyle = "spotlight";

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
            # hidden-bar cluster at the left end of the right section: the two
            # managed widgets, then the hiddenBar trigger. Order matters — for a
            # right-section trigger the managed widgets sit to its left and slide
            # out from the trigger (see plugins.nix hiddenBar), so the trigger
            # stays last in the cluster.
            { id = "ambientSound"; enabled = true; }
            { id = "simpleAudioControl"; enabled = true; }
            { id = "hiddenBar"; enabled = true; }
            { id = "systemTray"; enabled = true; }
            { id = "dankKDEConnect"; enabled = true; } # AvengeMedia DankKDEConnect
            { id = "usbManager"; enabled = true; }
            { id = "homeAssistantMonitor"; enabled = true; } # hyprland-only upstream
            { id = "claudeCodeUsage"; enabled = true; } # moved out of hidden bar, next to HA
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
          # translucent so the ext-background-effect blur behind the bar/widgets
          # is visible (fully opaque = no visible blur). Lower = more see-through.
          transparency = 0.3;
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
          # reveal a widget's popout on hover (not just on click).
          hoverPopouts = true;
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
        # battery tile — its detail view is DMS's native power-profile switcher
        # (performance/balanced/power-saver via power-profiles-daemon, enabled in
        # ./default.nix). There is no standalone power-profile CC widget.
        { id = "battery"; enabled = true; width = 50; }
        # plugin control-center toggles (id = "plugin_<pluginId>"). takeABreak's
        # tile is intentionally omitted — its pause toggle reaches the daemon via
        # an unreliable cross-instance lookup, so it's not useful here.
        { id = "plugin_typingSounds"; enabled = true; width = 50; }
      ];
    };
  };
}
