{ config, lib, ... }:
let
  # sops-decrypted Home Assistant token path (runtime tmpfs, never in the store).
  haTokenPath = config.sops.secrets.hass_token.path;
in
{
  config = lib.mkIf config.desktop.dms.enable {
    home.extraOptions = {
      # DMS plugins from the registry (github:AvengeMedia/dms-plugin-registry);
      # the registry homeModule (imported in ./default.nix) provides the pinned
      # src for each, we just enable + configure.
      programs.dank-material-shell.plugins = {
        aiOverviewControl = {
          enable = true; # bernardopg/AiOverviewControl
          settings.providerSelection = "claude"; # only show Claude usage
        };
        emojiLauncher.enable = true; # devnullvoid/dms-emoji-launcher
        homeAssistantMonitor = {
          enable = true; # xxyangyoulin/dms-plugin-hass (hyprland-only upstream)
          settings = {
            hassUrl = "https://ha.laxoi.be";
            hassTokenPath = haTokenPath; # sops-decrypted token file
          };
        };
        fullscreenPowerMenu = {
          enable = true; # JDKamalakar/DMS-Fullscreen_Power_Menu
          # slider labels -> keys; all 0..100 (plugin divides by 100).
          settings = {
            menuOpacity = 50; # "Menu Transparency"
            dimOpacity = 80; # "Background Dim Intensity"
            primaryTintEnabled = true; # "Primary Color Tint"
            tintIntensity = 10; # "Tint Intensity"
          };
        };
        # collapsible bar group (rdannenbring/widget-group): fold ambient sound,
        # simple audio control and the Claude/AI overview behind one button. The
        # bar widget id is "widgetGroup:<variant.id>" (see bar.nix rightWidgets).
        widgetGroup = {
          enable = true;
          settings.variants = [
            {
              id = "media";
              name = "Media & AI";
              icon = "widgets";
              display = "icon";
              mainTarget = "";
              targets = [
                "ambientSound"
                "simpleAudioControl"
                "aiOverviewControl"
              ];
            }
          ];
        };
        usbManager.enable = true; # NordicsSys/dms-usb-manager
        simpleAudioControl.enable = true; # Dadangdut33 SimpleAudioControl (bar-only)
        ambientSound.enable = true; # hthienloc/dms-ambient-sound
        dankBatteryAlerts.enable = true; # AvengeMedia DankBatteryAlerts
      };

      # write plugin_settings.json marking each enabled plugin active, so they
      # actually turn on (not just install). NB: makes plugin settings
      # HM-managed/read-only — set a plugin's options via plugins.<id>.settings
      # rather than the DMS UI.
      programs.dank-material-shell.managePluginSettings = true;

      # The HA plugin keeps its monitored-entity list as plugin *state* (read via
      # pluginService.loadPluginState), not a setting — so declare the state file
      # to make the selection reproducible. Read-only: change the list here rather
      # than in the plugin's GUI editor.
      home.file.".local/state/DankMaterialShell/plugins/homeAssistantMonitor_state.json".text =
        builtins.toJSON {
          entityIds = lib.concatStringsSep ", " [
            "light.lamp_otis"
            "sensor.temperature_otis"
            "sensor.humidity_otis"
            "sensor.temperature_humidity_sensor_otis_battery"
          ];
        };
    };
  };
}
