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

  # The TimeEdit feed URL carries a personal access key, so it can't sit in
  # hoshiCalendar's settings (world-readable store, public repo). A timer
  # fetches it from sops into this file instead.
  timetableFile = "/home/otis/.cache/hoshi/ugent.ics";

  # QML expects "<pluginDir>/result/bin/mouthguard-detector", normally built
  # in-place by `nix build .#detector` — impossible in a read-only store.
  # Pre-link it to dux-plugins' own packages.mouthguard-detector instead.
  # Our own plugins come from the dux-plugins input, not the registry's pinned
  # copy, so `nix flake update dux-plugins` (or --override-input) reaches them.
  ownPlugins = inputs.dux-plugins.packages.${pkgs.stdenv.hostPlatform.system};
  mouthGuardDetector = ownPlugins.mouthguard-detector;

  # Generated here (not the plugin's menu.jsonc) so setup.config/update.*
  # rows can point at this checkout. A list, not an attrset — Nix serialises
  # attrsets alphabetically and row order matters.
  flakeDir = "/home/otis/sitolamix";

  winappsCfg = config.services.winapps;

  dankMenuRows = [
    # Root
    {
      id = "apps";
      icon = "apps";
      label = "Apps";
      aliases = [
        "app"
        "applications"
      ];
      provider = "apps";
    }
    {
      id = "learn";
      icon = "school";
      label = "Learn";
    }
    {
      id = "trigger";
      icon = "bolt";
      label = "Trigger";
    }
    {
      id = "windows";
      icon = "desktop_windows";
      label = "Windows";
      aliases = [
        "office"
        "word"
        "excel"
        "vm"
      ];
      # Hides the whole subtree on a host without the VM.
      when = if winappsCfg.enable then "true" else "false";
    }
    {
      id = "style";
      icon = "palette";
      label = "Style";
    }
    {
      id = "setup";
      icon = "settings";
      label = "Setup";
      aliases = [ "settings" ];
    }
    {
      id = "update";
      icon = "sync";
      label = "Update";
      aliases = [ "rebuild" ];
    }
    {
      id = "system";
      icon = "power_settings_new";
      label = "System";
      aliases = [ "power-menu" ];
    }

    # Learn
    {
      id = "learn.keybinds";
      icon = "keyboard";
      label = "Keybinds";
      aliases = [
        "keys"
        "bindings"
      ];
      action = "dms ipc call keybinds open niri";
    }
    {
      id = "learn.keydrill";
      icon = "keyboard_command_key";
      label = "Keydrill";
      aliases = [
        "drill"
        "shortcuts"
      ];
      when = if config.apps.keydrill.enable then "true" else "false";
      # practiceCommand releases niri's key grabs first; ghostty is needed
      # for the Kitty keyboard protocol keydrill requires.
      action = "${config.desktop.niri.practiceCommand} run ghostty -e keydrill run --from niri";
    }
    {
      id = "learn.niri";
      icon = "grid_view";
      label = "Niri";
      target = "https://github.com/YaLTeR/niri/wiki";
    }
    {
      id = "learn.nixos";
      icon = "menu_book";
      label = "NixOS Manual";
      target = "https://nixos.org/manual/nixos/stable/";
    }
    {
      id = "learn.home-manager";
      icon = "home";
      label = "Home Manager Options";
      target = "https://nix-community.github.io/home-manager/options.xhtml";
    }
    {
      id = "learn.packages";
      icon = "search";
      label = "Search Packages";
      target = "https://search.nixos.org/packages";
    }

    # Trigger
    {
      id = "trigger.capture";
      icon = "screenshot_region";
      label = "Capture";
      aliases = [
        "screenshot"
        "annotate"
      ];
      # region capture straight into the annotation editor; other modes are
      # reachable from the plugin's own UI.
      action = "dms ipc call quickCapture screenshot region edit";
    }
    {
      id = "trigger.clipboard";
      icon = "content_paste";
      label = "Clipboard";
      aliases = [ "clip" ];
      action = "dms ipc call clipboard toggle";
    }
    {
      id = "trigger.notepad";
      icon = "edit_note";
      label = "Notepad";
      aliases = [ "notes" ];
      action = "dms ipc call notepad toggle";
    }
    {
      id = "trigger.emoji";
      icon = "mood";
      label = "Emoji";
      aliases = [
        "emoji"
        "emojis"
      ];
      action = "dms ipc call spotlight toggleQuery ':e '";
    }
    {
      id = "trigger.toggle";
      icon = "toggle_on";
      label = "Toggle";
      aliases = [ "toggles" ];
    }
    {
      id = "trigger.toggle.idle";
      icon = "coffee";
      label = "Stay Awake";
      aliases = [
        "caffeine"
        "inhibit"
      ];
      checked = "dms ipc call inhibit status | grep -q enabled";
      action = "dms ipc call inhibit toggle";
    }
    {
      id = "trigger.toggle.kanata";
      icon = "keyboard";
      label = "Home-row Mods";
      aliases = [
        "kanata"
        "homerow"
      ];
      when = if config.desktop.kanata.enable then "true" else "false";
      # Manual path for stopping kanata; gamemode already handles it for games.
      checked = "systemctl is-active --quiet kanata-default.service";
      action = "kanata-toggle";
    }
    {
      id = "trigger.toggle.night";
      icon = "nightlight";
      label = "Night Mode";
      aliases = [ "nightlight" ];
      checked = "dms ipc call night status | grep -q enabled";
      action = "dms ipc call night toggle";
    }

    # when/checked/disabled/labelCmd are shell snippets the plugin evaluates
    # live when this submenu opens.
    {
      id = "windows.status";
      icon = "memory";
      label = "Status";
      # e.g. "Running · CPU 4% · RAM 2.1GiB / 4GiB" — a snapshot, not a live meter.
      labelCmd = "winapps-status";
      disabled = "true"; # readout only, not a control
    }
    # start/stop go through winapps-vm, not systemctl, so manual and
    # on-demand starts announce themselves the same way.
    {
      id = "windows.start";
      icon = "play_arrow";
      label = "Start VM";
      aliases = [ "boot" ];
      when = "! systemctl is-active --quiet docker-windows";
      action = "winapps-vm start";
    }
    {
      id = "windows.stop";
      icon = "stop";
      label = "Stop VM";
      aliases = [ "shutdown" ];
      when = "systemctl is-active --quiet docker-windows";
      # Windows gets 120s to shut down cleanly.
      action = "winapps-vm stop";
    }
    {
      id = "windows.on-demand";
      icon = "auto_mode";
      label = "On-Demand";
      aliases = [
        "auto"
        "automatic"
      ];
      # On: VM starts on app launch and stops after an idle timeout. Off: manual.
      checked = "winapps-on-demand status";
      action = "winapps-on-demand toggle";
    }
    {
      id = "windows.desktop";
      icon = "desktop_windows";
      label = "Full Desktop";
      action = "winapps-run windows";
    }
    {
      id = "windows.viewer";
      icon = "monitor";
      label = "Web Console";
      aliases = [
        "console"
        "vnc"
        "install"
      ];
      # HTTP console — the only way in before RDP answers (first boot, broken
      # Windows). "Full Desktop" above is the everyday, faster RDP path.
      target = "http://127.0.0.1:8006";
    }

    # Style
    {
      id = "style.theme";
      icon = "colorize";
      label = "Theme";
      aliases = [
        "themes"
        "colors"
      ];
      action = "dms ipc call settings focusOrToggleWith theme";
    }
    {
      id = "style.wallpaper";
      icon = "wallpaper";
      label = "Wallpaper";
      aliases = [
        "background"
        "wall"
      ];
      action = "dms ipc call settings focusOrToggleWith wallpaper";
    }
    {
      # The picker you actually browse wallpapers with; every desktop colour
      # derives from it, so it's a theming control.
      id = "style.carousel";
      icon = "view_carousel";
      label = "Wallpaper carousel";
      aliases = [
        "carousel"
        "walls"
      ];
      action = "dms ipc call wallpaperCarousel toggle";
    }
    {
      id = "style.bar";
      icon = "width_normal";
      label = "Bar";
      aliases = [ "topbar" ];
      action = "dms ipc call settings focusOrToggleWith dankbar";
    }

    # Setup
    {
      id = "setup.config";
      icon = "code";
      label = "Edit Config";
      aliases = [
        "flake"
        "nix"
      ];
      action = "ghostty --working-directory=${flakeDir} -e nvim ${flakeDir}/flake.nix";
    }
    {
      id = "setup.displays";
      icon = "monitor";
      label = "Displays";
      aliases = [
        "monitors"
        "screens"
      ];
      action = "dms ipc call settings focusOrToggleWith displays";
    }
    {
      id = "setup.network";
      icon = "wifi";
      label = "Network";
      aliases = [ "wlan" ];
      action = "dms ipc call settings focusOrToggleWith network";
    }
    {
      id = "setup.control-center";
      icon = "tune";
      label = "Control Center";
      aliases = [
        "audio"
        "bluetooth"
      ];
      action = "dms ipc call control-center toggle";
    }
    {
      id = "setup.settings";
      icon = "settings";
      label = "All Settings";
      action = "dms ipc call settings open";
    }

    # Each runs in a terminal — long, can fail, a detached process would hide both.
    {
      id = "update.rebuild";
      icon = "build";
      label = "Rebuild";
      action = "ghostty --working-directory=${flakeDir} -e just rebuild";
    }
    {
      id = "update.update";
      icon = "sync";
      label = "Update Inputs + Rebuild";
      action = "ghostty --working-directory=${flakeDir} -e just update";
    }
    {
      id = "update.diff";
      icon = "difference";
      label = "Diff Generations";
      action = "ghostty --working-directory=${flakeDir} -e just diff";
    }
    {
      id = "update.check";
      icon = "fact_check";
      label = "Check Config";
      action = "ghostty --working-directory=${flakeDir} -e just doctor";
    }
    {
      id = "update.shell";
      icon = "restart_alt";
      label = "Restart Shell";
      action = "systemctl --user restart dms.service";
    }

    # System
    {
      id = "system.lock";
      icon = "lock";
      label = "Lock";
      action = "loginctl lock-session";
    }
    {
      id = "system.suspend";
      icon = "bedtime";
      label = "Suspend";
      action = "systemctl suspend";
    }
    {
      id = "system.logout";
      icon = "logout";
      label = "Logout";
      action = "niri msg action quit --skip-confirmation";
    }
    {
      id = "system.reboot";
      icon = "restart_alt";
      label = "Reboot";
      action = "systemctl reboot";
    }
    {
      id = "system.shutdown";
      icon = "power_settings_new";
      label = "Shutdown";
      action = "systemctl poweroff";
    }
  ];

  dankMenuFile = pkgs.writeText "dankmenu.jsonc" ''
    {
    ${lib.concatMapStringsSep ",\n" (
      r: "  ${builtins.toJSON r.id}: ${builtins.toJSON (builtins.removeAttrs r [ "id" ])}"
    ) dankMenuRows}
    }
  '';

  # The registry's own builds, to patch one before handing it back as src.
  registryPlugins = import "${inputs.dux-plugin-registry}/nix" { inherit pkgs; };

  # The glow runs a bare `python3` expecting numpy and Pillow on PATH; point
  # it at a Python that has them.
  audioFxPlugin = pkgs.runCommand "dms-plugin-audiofx-patched" { } ''
    cp -r ${registryPlugins.audioFx} $out
    chmod -R u+w $out
    substituteInPlace $out/AudioFxGlow.qml --replace-fail \
      '["python3", root.script' \
      '["${
        pkgs.python3.withPackages (ps: [
          ps.numpy
          ps.pillow
        ])
      }/bin/python3", root.script'
    # Pre-2.0 cache dir; Dux Shell 2.0 uses ~/.cache/dms.
    substituteInPlace $out/audiofx-glow.py \
      --replace-fail '~/.cache/DankMaterialShell/' '~/.cache/dms/'
    # The player disc's DankAlbumArt is gone in Dux Shell 2.0, and one broken
    # component stops the whole plugin, glow included. MediaArtwork draws the
    # same round cover. Drop once upstream supports 2.0.
    sed -i '/DankAlbumArt {/,/showAnimation: false/{
      s/DankAlbumArt {/MediaArtwork {/
      s/root\.artSpan/root.coverSize/
      s/activePlayer: root\.player/cornerRadius: width \/ 2/
      s/artUrl: root\.hiResArt/artUrl: root.hiResArt || (root.player?.trackArtUrl ?? "")/
      /albumSize:/d
      /showAnimation:/d
    }' $out/AudioFxDiscDesktop.qml
    grep -q 'MediaArtwork {' $out/AudioFxDiscDesktop.qml
  '';

  mouthGuardPlugin = pkgs.runCommand "dms-plugin-mouthguard" { } ''
    mkdir -p $out
    cp -r ${inputs.dux-plugins}/plugins/mouthguard/. $out/
    chmod -R u+w $out
    ln -s ${mouthGuardDetector} $out/result
  '';
in
{
  config = lib.mkIf config.desktop.dux-shell.enable {
    # Key-injection backend for virtualKeyboard. No NixOS module for the
    # daemon exists, so it's hand-rolled: load uinput, run ydotoold, point
    # dms.service at it below.
    boot.kernelModules = [ "uinput" ];
    environment.systemPackages = [
      pkgs.ydotool
      # QalcService.qml spawns a bare `qalc` on load, before qalcCommand's
      # path applies — needs qalc on PATH or it hangs on "Calculating...".
      pkgs.libqalculate
      pkgs.cava # audioFx's visualizer and glow
    ];
    systemd.services.ydotoold = {
      description = "ydotool daemon";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=/run/ydotoold.socket --socket-perm=0666";
        Restart = "always";
      };
    };

    sops.secrets.ugent_timetable_url = {
      sopsFile = ../../../secrets/ugent.yaml;
      owner = "otis";
      mode = "0400";
    };

    home.extraOptions = {
      systemd.user = {
        services.hoshi-timetable = {
          # Before dms: hoshi loads its sources once at startup, so a fetch
          # landing after that shows an error until its next refresh.
          Unit = {
            Description = "Fetch the UGent timetable for hoshiCalendar";
            Before = [ "dms.service" ];
          };
          Install.WantedBy = [ "dms.service" ];
          Service = {
            Type = "oneshot";
            # Write-then-rename, so a failed fetch keeps the last good copy.
            ExecStart = pkgs.writeShellScript "hoshi-timetable" ''
              set -eu
              mkdir -p "$(dirname ${timetableFile})"
              ${pkgs.curl}/bin/curl -fsSL --retry 3 --max-time 20 \
                -o ${timetableFile}.tmp "$(cat ${config.sops.secrets.ugent_timetable_url.path})"
              mv ${timetableFile}.tmp ${timetableFile}
            '';
          };
        };
        timers.hoshi-timetable = {
          Timer = {
            OnStartupSec = "1min";
            OnUnitActiveSec = "1h";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };

      # Plugins from github:duxlabs-dev/dux-plugin-registry; its homeModule
      # provides the pinned src for each — we just enable + configure.
      programs.dank-material-shell.plugins = {
        claudeCodeUsage = {
          enable = true; # titeya/dms-claudecode (needs jq+curl, both in systemPackages)
          settings.refreshInterval = 2; # minutes (SliderSetting range 2..15)
        };
        emojiLauncher.enable = true; # devnullvoid/dms-emoji-launcher
        calculator = {
          enable = true; # rochacbruno/DankCalculator — launcher plugin
          settings = {
            # libqalculate over the built-in JS engine: handles units,
            # currencies, hex.
            calcEngine = "qalc";
            qalcCommand = "${pkgs.libqalculate}/bin/qalc -i -t -set \"decimal comma off\" -c 0";
            # Both set explicitly — CalculatorSettings.qml only syncs
            # noTrigger/trigger from the UI, not from Nix values.
            noTrigger = false;
            trigger = "=";
          };
        };
        dankKDEConnect.enable = true; # duxlabs-dev/dux-plugins DankKDEConnect (bar widget; kdeconnect via kde-connect.nix)
        # keybind search under "\", reads live from `dms keybinds show niri`.
        dankLauncherKeys.enable = true; # duxlabs-dev/dux-plugins DankLauncherKeys
        # unified cpu/ram/disk gauges, replacing the built-in memUsage + diskUsage widgets.
        systemMonitorPlus = {
          enable = true;
          settings = {
            resourceOrder = "cpuUsage,ramUsage,diskPartitionUsage"; # only these three show
            cpuUsageEnabled = true;
            ramUsageEnabled = true;
            diskPartitionUsageEnabled = true;
            diskPartitionUsageMount = "/";
            cpuUsageVisualStyle = "gauge";
            ramUsageVisualStyle = "gauge";
            diskPartitionUsageVisualStyle = "gauge";
            cpuUsageShowText = false; # icon-only: gauge + icon, no percentage text
            ramUsageShowText = false;
            diskPartitionUsageShowText = false;
            # fixed colour (theme primary) instead of value-threshold colouring
            cpuUsageUseValueColors = false;
            ramUsageUseValueColors = false;
            diskPartitionUsageUseValueColors = false;
          };
        };
        # Screenshot + annotation editor (Mod+S or its control-center tile);
        # captures via DMS's own `dms screenshot`, no external editor needed.
        quickCapture = {
          enable = true; # hthienloc/dms-quick-capture
          settings = {
            # "rust", the alternative backend, downloads its binary from
            # GitHub at runtime — impossible under a read-only store.
            screenshotBackend = "dms";
          };
        };
        # Fullscreen wallpaper carousel (Mod+Alt+W) — fastest re-theme since
        # every colour derives from the wallpaper.
        wallpaperCarousel.enable = true; # motor-dev/wallpaperCarousel

        niriDS.enable = true; # hthienloc/dms-niri-display-settings (needs wl-mirror)
        homeAssistantMonitor = {
          enable = true; # xxyangyoulin/dms-plugin-hass (hyprland-only upstream)
          settings = {
            hassUrl = "https://ha.laxoi.be";
            hassTokenPath = haTokenPath; # sops-decrypted token file
          };
        };
        # Local project — webcam mouth-closure tracker. Needs the video
        # group and QtMultimedia on the QML path for its SoundEffect alerts.
        mouthGuard = {
          enable = true;
          # mkForce: registry sets src at normal priority too, and its tree
          # lacks the detector symlink built above.
          src = lib.mkForce mouthGuardPlugin;
        };
        # Omarchy-style root menu (Mod+Space). Tree generated above so rows
        # can reference this checkout. To iterate on the plugin itself:
        # nh os build/switch --override-input dux-plugins path:/home/otis/Documents/dms-plugins .
        dankMenu = {
          enable = true;
          src = lib.mkForce ownPlugins.dankmenu;
          settings.menuPath = "${dankMenuFile}";
        };
        # .ics calendar as a bar pill and desktop widget (TheDoukiDrift/hoshiCalendar).
        hoshiCalendar = {
          enable = true;
          settings = {
            # { source = "<path or https/webcal URL>"; name = "<label>"; }
            sources = [
              {
                source = timetableFile; # fetched below; the feed URL is a secret
                name = "UGent";
              }
            ];
            # Re-reads the local file, so fetches show up within 15 min.
            refreshMinutes = 15;
          };
        };
        virtualKeyboard = {
          enable = true; # end-4/dots-hyprland port
          src = lib.mkForce ownPlugins.virtualkeyboard;
        };
        usbManager.enable = true; # NordicsSys/dms-usb-manager
        # Left off: can only show VM status, not start it (oci-containers run
        # with --rm, so a stopped container doesn't exist to start), and
        # would be a permanent bar widget for a VM that's usually off.
        # dankMenu's windows subtree covers status instead.
        dockerManager.enable = false;
        ambientSound.enable = true; # bar widget, no control-center variant
        # dankBatteryAlerts dropped (moved into DMS core Settings > Battery >
        # Alerts). kbdBacklightOSD also tried but dropped — this laptop has
        # no kernel-visible keyboard backlight.
        batteryOSD.enable = true;
        # Charge-history popout + power-profile switcher; replaces the
        # control-center pill's own battery icon.
        batteryPlus.enable = true;
        # satoshoe-dev/dms-audiofx, for its wallpaper glow only: the bright
        # spots of the wallpaper pulse to the music. The edge visualizer is
        # off and the player disc is never placed. No place-within-backdrop
        # rule (upstream's README has one): DMS's wallpaper is on the
        # workspaces, so the backdrop would put the glow underneath it.
        audioFx = {
          enable = true;
          src = lib.mkForce audioFxPlugin;
          settings = {
            glowOn = true;
            glowStrength = 10; # percent, 10-300 (the plugin's minimum)
            on = false; # edge visualizer
          };
        };
      };

      # Marks plugins active (not just installed), and makes settings
      # HM-managed/read-only — set via plugins.<id>.settings, not the DMS UI.
      programs.dank-material-shell.managePluginSettings = true;

      # Ydotool.qml reads YDOTOOL_SOCKET for ydotoold's socket above. Merges
      # with default.nix's entries for the same unit.
      systemd.user.services.dms.Service.Environment = [
        "YDOTOOL_SOCKET=/run/ydotoold.socket"
      ];

      # Monitored-entity list is plugin state, not a setting — declare the
      # file for reproducibility. Change it here, not in the GUI.
      home.file.".local/state/dms/plugins/homeAssistantMonitor_state.json".text = builtins.toJSON {
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
