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
        claudeCodeUsage.enable = true; # titeya/dms-claudecode (needs jq+curl, both in systemPackages)
        emojiLauncher.enable = true; # devnullvoid/dms-emoji-launcher
        calculator.enable = true; # rochacbruno/DankCalculator — launcher plugin, trigger "=" in spotlight
        dankKDEConnect.enable = true; # AvengeMedia/dms-plugins DankKDEConnect (bar widget; kdeconnect via kde-connect.nix)
        # unified system monitor (Dadangdut33/dms-plugins) — replaces the
        # built-in memUsage + diskUsage bar widgets with one widget showing
        # cpu/ram/disk as gauges.
        systemMonitorPlus = {
          enable = true;
          settings = {
            # only cpu, ram, disk show (every other resource's <r>Enabled
            # defaults to false); this also fixes their order.
            resourceOrder = "cpuUsage,ramUsage,diskPartitionUsage";
            cpuUsageEnabled = true;
            ramUsageEnabled = true;
            diskPartitionUsageEnabled = true;
            diskPartitionUsageMount = "/"; # root filesystem
            # gauge (circular speedometer ring) look
            cpuUsageVisualStyle = "gauge";
            ramUsageVisualStyle = "gauge";
            diskPartitionUsageVisualStyle = "gauge";
            # icon-only: drop the numeric percentage text, keep the gauge + icon.
            cpuUsageShowText = false;
            ramUsageShowText = false;
            diskPartitionUsageShowText = false;
            # fixed color (UseValueColors=false disables the auto
            # normal/warning/danger threshold colouring; colour = theme primary).
            cpuUsageUseValueColors = false;
            ramUsageUseValueColors = false;
            diskPartitionUsageUseValueColors = false;
          };
        };
        # IPC-only screenshot + screen-record toolbar; opened via keybind
        # (dms ipc call screenCaptureToolbar toggle). Deps: gpu-screen-recorder
        # (media suite), grim/slurp/wl-clipboard (niri), satty (added below).
        screenCaptureToolbar.enable = true; # JDKamalakar/DMS-ScreenCapture_Toolbar
        # control-center plugins (no bar widget, so NOT hideable by the hidden
        # bar): typing sounds daemon + a break reminder. They surface as
        # control-center toggles.
        typingSounds = {
          enable = true; # hthienloc/dms-typing-sounds (needs evtest/libinput/ffmpeg + input group)
          settings = {
            # No sounds by default WITHOUT the plugin showing as disabled: the
            # "Enable Typing Sounds" toggle is settingKey "enabled", which is
            # ALSO the key DMS's loader uses to activate the plugin — setting it
            # false at startup makes DMS never load it (shows disabled in the
            # browser). So keep it enabled/loaded and just mute it via volume=0.
            # Raise this (0..100) in Settings to actually hear it.
            volume = 0;
            mouseEnabled = true;
          };
        };
        takeABreak = {
          enable = true; # hthienloc/dms-take-a-break
          # overlay = the fullscreen break screen dim; preWarning = the toast
          # before a break. Both 0..100 (%). GUI edits to these revert because
          # plugin settings are Nix-managed (managePluginSettings), so set here.
          settings = {
            overlayOpacity = 80;
            preWarningOpacity = 80;
          };
        };
        homeAssistantMonitor = {
          enable = true; # xxyangyoulin/dms-plugin-hass (hyprland-only upstream)
          settings = {
            hassUrl = "https://ha.laxoi.be";
            hassTokenPath = haTokenPath; # sops-decrypted token file
          };
        };
        # bartender-style bar collapser (hthienloc/dms-hidden-bar): the
        # "hiddenBar" trigger widget (see bar.nix rightWidgets) hides the three
        # media/AI widgets sitting next to it and reveals them on hover. Widgets
        # are managed by id within the trigger's own bar section. NB: DMS must be
        # restarted (`dms restart` / relogin) after adding/moving the managed
        # widgets before the plugin picks them up.
        hiddenBar = {
          enable = true;
          settings = {
            # whitelist = hide ONLY these ids (blacklist/auto would hide more).
            # (claudeCodeUsage moved out next to the HA widget; typingSounds and
            # takeABreak aren't bar widgets so they can't be hidden here.)
            widgetSelectionMode = "whitelist";
            widgetWhitelist = [
              "ambientSound"
              "simpleAudioControl"
            ];
            # click to expand (no hover reveal), then auto-collapse after the
            # inactivity delay. Right-click pins to prevent auto-collapse.
            autoExpand = false;
            autoCollapse = true;
          };
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
