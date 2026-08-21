{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # sops-decrypted Home Assistant token path (runtime tmpfs, never in the store).
  haTokenPath = config.sops.secrets.hass_token.path;

  # ── MouthGuard ────────────────────────────────────────────────────────────
  # sitolam/dms-mouthguard is not in dms-plugin-registry (it's a local project,
  # see the flake input), so instead of just flipping `enable` we hand the same
  # plugins.<id> option a `src` we assemble here.
  #
  # StartupCheck.qml and MouthGuardDaemon.qml both resolve the detector as
  # "<pluginDir>/result/bin/mouthguard-detector" — the artifact of running
  # `nix build .#detector` *inside* the plugin directory. Under any Nix install
  # the plugin directory is a read-only store path, so that build can never
  # happen there; pre-create the symlink those two files look for instead,
  # pointing at the very package that `nix build .#detector` would have made.
  #
  # That package is assembled here rather than taken from the plugin flake's
  # `packages` output: the flake builds it from a bare nixpkgs instance we
  # cannot add overlays to (same trap as niri, see ../niri/default.nix), and it
  # needs the dlib pin below. Keep these deps in sync with `pythonEnv` in
  # dms-mouthguard's flake.nix.
  mouthGuardPython = pkgs.python3.withPackages (
    ps: with ps; [
      dlib
      opencv4
      numpy
      face-recognition-models
    ]
  );

  # detector.py imports mouthguard_core, which sits next to it in the plugin
  # source root — so run it in place, sys.path[0] resolves the import.
  mouthGuardDetector = pkgs.writeShellScriptBin "mouthguard-detector" ''
    exec ${mouthGuardPython}/bin/python3 ${inputs.dms-mouthguard}/detector.py "$@"
  '';

  # ── dankMenu (DEVELOPMENT) ────────────────────────────────────────────────
  # A store path that is *itself* a symlink to the working checkout — what
  # home-manager's lib.file.mkOutOfStoreSymlink builds, inlined because that
  # helper lives in the home-manager module scope and this file writes into
  # home.extraOptions from the NixOS side. The point is that the plugin DMS
  # loads is the live directory, so `dms ipc call plugins reload dankMenu`
  # picks up edits without a rebuild.
  dankMenuDevSrc = pkgs.runCommandLocal "dms-plugin-dankmenu-dev" { } ''
    ln -s /home/otis/Documents/dms-plugins/plugins/dankmenu $out
  '';

  mouthGuardPlugin = pkgs.runCommand "dms-plugin-mouthguard" { } ''
    mkdir -p $out
    cp -r ${inputs.dms-mouthguard}/. $out/
    chmod -R u+w $out
    ln -s ${mouthGuardDetector} $out/result
  '';
in
{
  config = lib.mkIf config.desktop.dms.enable {
    # nixpkgs bumped dlib 20.0 -> 20.0.1 (2026-08-18) without refreshing
    # python3Packages.dlib: build-cores.patch no longer applies, and 20.0.1's
    # setup.py dropped the `--set` build flag the nix expression feeds it, so
    # the python binding fails to build on unstable. Pin the src back to 20.0 —
    # what stable ships, and what the binary cache already has. Only mouthGuard
    # pulls dlib in. Drop once nixpkgs fixes python3Packages.dlib.
    nixpkgs.overlays = [
      (_final: prev: {
        dlib = prev.dlib.overrideAttrs (_: rec {
          version = "20.0";
          src = prev.fetchFromGitHub {
            owner = "davisking";
            repo = "dlib";
            tag = "v${version}";
            sha256 = "sha256-VTX7s0p2AzlvPUsSMXwZiij+UY9g2y+a1YIge9bi0sw=";
          };
        });
      })
    ];

    home.extraOptions = {
      # DMS plugins from the registry (github:AvengeMedia/dms-plugin-registry);
      # the registry homeModule (imported in ./default.nix) provides the pinned
      # src for each, we just enable + configure.
      programs.dank-material-shell.plugins = {
        claudeCodeUsage = {
          enable = true; # titeya/dms-claudecode (needs jq+curl, both in systemPackages)
          # how often to fetch usage data, in minutes (SliderSetting range 2..15).
          settings.refreshInterval = 2;
        };
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
        # local project (see the `let` block) — webcam mouth-closure tracker.
        # Needs the `video` group (users.nix) and QtMultimedia on the QML path
        # (default.nix) for its SoundEffect alerts.
        mouthGuard = {
          enable = true;
          src = mouthGuardPlugin;
        };
        # DEVELOPMENT: dankMenu points at the live checkout via an
        # out-of-store symlink, so edits show up on `dms ipc call plugins
        # reload dankMenu` without a rebuild. It has to be declared here
        # rather than enabled in the DMS GUI because managePluginSettings
        # makes plugin_settings.json a read-only store symlink, and that file
        # is what the loader reads `enabled` from.
        # Replaced by the flake input + generated tree once the plugin lands.
        dankMenu = {
          enable = true;
          src = dankMenuDevSrc;
        };
        usbManager.enable = true; # NordicsSys/dms-usb-manager
        ambientSound.enable = true; # hthienloc/dms-ambient-sound (bar widget — no control-center variant)
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
        builtins.toJSON
          {
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
