{ config, lib, ... }:
let
  common = {
    displayPreferences = [ "all" ];
    syncPositionAcrossScreens = true;
  };
  widget = id: widgetType: enabled: cfg: {
    inherit id widgetType enabled;
    config = common // cfg;
  };

  # DMS's lockWidgetDefaults (DCommon SharedSettingsSpec.js) with the clock
  # and the password field changed. The whole list is declared because a
  # list in settings.json replaces DMS's default instead of merging with it.
  lockWidgets = [
    (widget "lock_clock" "desktopClock" true {
      style = "digital"; # default "expressive"
      transparency = 0;
      weight = 0;
      twoTone = true;
      showDate = false;
      showDigitalSeconds = false;
      showAnalogNumbers = false;
      showAnalogSeconds = true;
      # Placed by hand; the position lives in session.json (seeded in
      # ./default.nix).
      autoPosition = false;
      colorMode = "default";
    })
    (widget "lock_date" "lockDate" false {
      format = "short";
      colorMode = "default";
    })
    (widget "lock_auth" "lockAuth" true {
      style = "ring"; # default "expressive"
      profileVisibility = "always";
      passwordVisibility = "always";
    })
    (widget "lock_notifications" "lockNotifications" true { mode = 2; })
    (widget "lock_status" "lockStatus" true {
      showMediaPlayer = true;
      showWeather = true;
      background = false;
    })
    (widget "lock_power" "lockPower" false { shape = "round"; })
  ];

  # Same rule as DMS's greeterWidgetsFromLock: with greeterFollowLockScreen
  # (default) DMS rebuilds this list from the lock list and writes it back
  # unless it already matches, which a read-only settings.json can't take.
  greeterTypes = [
    "desktopClock"
    "lockDate"
    "lockAuth"
    "lockStatus"
    "lockPower"
  ];
in
{
  config = lib.mkIf config.desktop.dux-shell.enable {
    home.extraOptions.programs.dank-material-shell.settings = {
      lockScreenWidgetInstances = lockWidgets;
      greeterWidgetInstances = lib.filter (w: lib.elem w.widgetType greeterTypes) lockWidgets ++ [
        (widget "greeter_session" "greeterSession" true { })
      ];

      # DMS mirrors this from lock_power's enabled flag for older greeters.
      lockScreenShowPowerActions = false;
      lockBeforeSuspend = true;
    };
  };
}
