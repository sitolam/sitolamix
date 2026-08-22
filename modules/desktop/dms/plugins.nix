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
  # MouthGuard lives in sitolam/dms-plugins, not in dms-plugin-registry, so
  # instead of just flipping `enable` we hand the same plugins.<id> option a
  # `src` we assemble here from that input's plugins/mouthguard subtree.
  #
  # StartupCheck.qml and MouthGuardDaemon.qml both resolve the detector as
  # "<pluginDir>/result/bin/mouthguard-detector" — the artifact of running
  # `nix build .#detector` *inside* the plugin directory. Under any Nix install
  # the plugin directory is a read-only store path, so that build can never
  # happen there; pre-create the symlink those two files look for instead,
  # pointing at the very package that `nix build .#detector` would have made.
  #
  # That is now dms-plugins' own `packages.mouthguard-detector`, rather than a
  # hand-assembled copy of its python environment. The copy existed because
  # that flake builds from its own nixpkgs instance, which this config cannot
  # add overlays to (same trap as niri, see ../niri/default.nix), and the dlib
  # pin below had to reach the detector. Since the detector moved from dlib to
  # MediaPipe Face Mesh on OpenVINO it needs no overlay — and it now carries
  # things this config would otherwise have to reproduce exactly: the two
  # pinned MediaPipe model files, and the NPU runtime (Intel's NPU graph
  # compiler, which nixpkgs does not package, placed where OpenVINO looks for
  # it). Duplicating that here would be the same trap in reverse.
  mouthGuardDetector =
    inputs.dms-plugins.packages.${pkgs.stdenv.hostPlatform.system}.mouthguard-detector;

  # ── dankMenu ──────────────────────────────────────────────────────────────
  # The menu tree, generated here rather than taken from the plugin's own
  # menu.jsonc, so rows can point at this flake's checkout. Everything that is
  # machine-agnostic still matches the bundled default; the `setup.config` and
  # `update.*` rows are the reason this exists at all.
  #
  # Schema is omarchy's (basecamp/omarchy, default/omarchy/omarchy-menu.jsonc):
  # dotted keys imply hierarchy, the kind of a row is inferred from its fields,
  # and `when` / `checked` / `disabled` are shell snippets the plugin evaluates
  # one level at a time.
  #
  # This is written as an ordered *list* rather than an attrset because Nix
  # serialises attrsets alphabetically, and menu rows have a meaningful order:
  # a power menu reading "lock, logout, reboot, shutdown, suspend" is not the
  # one anybody wants. The plugin's parser reads declaration order, so emitting
  # ordered JSONC text preserves it.
  flakeDir = "/home/otis/sitolamix";

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
        "screenrecord"
      ];
      action = "dms ipc call screenCaptureToolbar toggle";
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
      id = "trigger.toggle.night";
      icon = "nightlight";
      label = "Night Mode";
      aliases = [ "nightlight" ];
      checked = "dms ipc call night status | grep -q enabled";
      action = "dms ipc call night toggle";
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

    # Update — each runs in a terminal: they are long, they can fail, and a
    # detached process would hide both.
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

  mouthGuardPlugin = pkgs.runCommand "dms-plugin-mouthguard" { } ''
    mkdir -p $out
    cp -r ${inputs.dms-plugins}/plugins/mouthguard/. $out/
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
    # what stable ships, and what the binary cache already has. howdy is the
    # only consumer left (its passthru.pythonDeps lists dlib); mouthGuard used
    # to be the other one and no longer touches dlib at all. Drop once nixpkgs
    # fixes python3Packages.dlib.
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
        # control-center plugin (no bar widget, so NOT hideable by the hidden
        # bar): a break reminder, surfaces as a control-center toggle.
        # niriDS below is its own bar-widget control-center tile instead.
        niriDS.enable = true; # hthienloc/dms-niri-display-settings (needs wl-mirror), in dms-plugin-registry
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
        # omarchy-style root menu, bound to Mod+Space in ../niri/bindings.nix.
        # The tree is generated below rather than taken from the plugin's own
        # menu.jsonc so rows can reference this checkout; the bundled file is
        # only the default for a standalone install.
        dankMenu = {
          enable = true;
          src = "${inputs.dms-plugins}/plugins/dankmenu";
          settings.menuPath = "${dankMenuFile}";
        };
        usbManager.enable = true; # NordicsSys/dms-usb-manager
        ambientSound.enable = true; # hthienloc/dms-ambient-sound (bar widget — no control-center variant)
        dankBatteryAlerts.enable = true; # AvengeMedia DankBatteryAlerts
        # notsopreety/batteryOSD — not in dms-plugin-registry, so pinned as its
        # own flake input (flake.nix) and pointed at directly, same as
        # dankMenu/mouthGuard above. (Its sibling kbdBacklightOSD was tried
        # too, but this laptop has no kernel-visible keyboard backlight — no
        # /sys/class/leds/*kbd_backlight* node, no UPower KbdBacklight D-Bus
        # object — so that plugin was inert and got dropped.)
        batteryOSD = {
          enable = true;
          src = inputs.battery-osd;
        };
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
