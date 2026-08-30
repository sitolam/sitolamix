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
  # MouthGuard lives in sitolam/dms-plugins. The registry has since adopted it
  # (plugins/sitolam-mouthguard.json), but we still hand the same plugins.<id>
  # option a `src` assembled here from that input's plugins/mouthguard subtree
  # — see the mkForce note at the option itself for why ours has to win.
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
  # add overlays to (same trap as niri, see ../niri/default.nix), and a dlib
  # pin this file used to carry had to reach the detector. Since the detector
  # moved from dlib to MediaPipe Face Mesh on OpenVINO it needs no overlay — and
  # it now carries things this config would otherwise reproduce exactly: the two
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
      # The whole subtree disappears on a host without the VM, rather than
      # offering rows that would fail.
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

    # Windows — the VM is deliberately not running most of the time. `when` /
    # `checked` / `disabled` / `labelCmd` are shell snippets the plugin
    # evaluates when this submenu opens, so every row below reads the unit's
    # real state rather than describing it.
    {
      id = "windows.status";
      icon = "memory";
      label = "Status";
      # labelCmd replaces the label with this snippet's output — the only way
      # to show a live figure, since the menu tree itself is a static file.
      # Reads "Stopped", or "Running · CPU 4% · RAM 2.1GiB / 4GiB". A snapshot
      # taken when the menu opens, not a running meter.
      labelCmd = "winapps-status";
      # A readout, not a control. Without this a row with no action would be
      # treated as an empty submenu to descend into.
      disabled = "true";
    }
    # One button, two definitions: `when` makes them mutually exclusive, so
    # exactly one is ever on screen and it is always the one that does
    # something. Both go through winapps-vm rather than systemctl directly, so
    # a manual start announces itself the same way an on-demand one does.
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
      # Windows gets 120s to shut down cleanly (see ../../services/winapps).
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
      # When on, opening Word starts the VM and waits for it, and the VM shuts
      # itself down after services.winapps.idleTimeout minutes with no
      # RemoteApp session open. When off, the VM is yours to start and stop.
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
      # dockurr/windows serves the guest's actual screen over HTTP. This is the
      # only way in when RDP is not answering — during the 20-40 minute first
      # boot, and afterwards if Windows breaks in a way that takes RDP with it.
      # "Full Desktop" above is the everyday one: same desktop over RDP, which
      # is far faster and properly integrated.
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
    # ydotool: key-injection backend for the virtualKeyboard plugin (raw
    # keycode press/release, so shift/ctrl/alt can be held across separate
    # taps — see plugins/virtualkeyboard/StartupCheck.qml, which blocks the
    # plugin from enabling if this isn't reachable). uinput needs a kernel
    # module and root (or a group with /dev/uinput access) to open, and
    # nixpkgs ships no dedicated NixOS module for the daemon, so both are
    # hand-rolled here: load the module, run ydotoold as a system service
    # with a world-writable socket, and point dms.service at that socket
    # (added to systemd.user.services.dms.Service.Environment below).
    boot.kernelModules = [ "uinput" ];
    environment.systemPackages = [ pkgs.ydotool ];
    systemd.services.ydotoold = {
      description = "ydotool daemon";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=/run/ydotoold.socket --socket-perm=0666";
        Restart = "always";
      };
    };

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
            # Rarer and shorter than the plugin defaults (20m / 20s / 3 / 5m):
            # the 20-minute cadence interrupted too often.
            shortBreakInterval = 45; # minutes between short breaks
            shortBreakDuration = 10; # seconds per short break
            shortBreaksBeforeLong = 4; # so a long break lands every 3h
            longBreakDuration = 2; # minutes
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
          # mkForce is required, not stylistic: dms-plugin-registry has adopted
          # this plugin (plugins/sitolam-mouthguard.json) and its module sets
          # every plugin's `src` at normal priority, not mkDefault — so without
          # this the two definitions conflict and evaluation fails outright.
          #
          # Ours has to win for two reasons. The registry would install the
          # plugin tree alone, without the `result` symlink to the detector its
          # QML resolves (see the `let` block above). And this is our own
          # plugin: sourcing it from the dms-plugins input means a push to that
          # repo plus `nix flake update dms-plugins` lands here immediately,
          # instead of waiting on the registry's prefetch to catch up — which
          # is the whole point when iterating on it.
          src = lib.mkForce mouthGuardPlugin;
        };
        # omarchy-style root menu, bound to Mod+Space in ../niri/bindings.nix.
        # The tree is generated below rather than taken from the plugin's own
        # menu.jsonc so rows can reference this checkout; the bundled file is
        # only the default for a standalone install.
        dankMenu = {
          enable = true;
          # mkForce for the same reason as mouthGuard above — the registry
          # adopted this one too (plugins/sitolam-dankmenu.json), and its `src`
          # is not mkDefault, so the two definitions conflict without this.
          # Also ours: kept on the dms-plugins input so testing a change is a
          # push plus `nix flake update dms-plugins`, not a registry refresh.
          src = lib.mkForce "${inputs.dms-plugins}/plugins/dankmenu";
          settings.menuPath = "${dankMenuFile}";
        };
        # on-screen keyboard, ported from end-4/dots-hyprland. Not yet in the
        # registry (unlike dankMenu/mouthGuard above), so no mkForce needed —
        # this is the only definition. While iterating before it's pushed,
        # test with `nh os build/switch --override-input dms-plugins
        # path:/home/otis/Documents/dms-plugins .` (or whatever the working
        # checkout's path is) so uncommitted edits are picked up.
        virtualKeyboard = {
          enable = true;
          src = "${inputs.dms-plugins}/plugins/virtualkeyboard";
        };
        usbManager.enable = true; # NordicsSys/dms-usb-manager
        # barDropdown — local, see the dms-plugins checkout. One bar button that
        # drops a panel of real bar widgets *below* the bar.
        #
        # This is the third attempt at collapsing this cluster, and the first
        # that can work. hthienloc/dms-hidden-bar and rdannenbring/widget-group
        # both collapse widgets along the bar and reveal them the same way, and
        # in a side section that reveal has nowhere to go: DankBarContent.qml
        # anchors the three sections independently (left to parent.left, right
        # to parent.right, centre to parent.horizontalCenter), so a wider
        # right-section widget only pushes its own section's left edge into the
        # empty middle of the bar. The centre widgets never move, and because
        # the centre section paints last, a wide enough expansion ends up
        # underneath the clock. No plugin setting changes that.
        #
        # barDropdown does not expand along the bar at all: the members go in a
        # popout that DMS anchors under the trigger and paints over the windows
        # below. Nothing on the bar moves and nothing overlaps.
        #
        # As with virtualKeyboard below, the src is the plugin subtree of the
        # dms-plugins input rather than a registry entry — this one is ours and
        # is not in the registry.
        barDropdown = {
          enable = true;
          src = "${inputs.dms-plugins}/plugins/bardropdown";
          settings = {
            # member bar-widget ids, left to right in the panel. They are
            # deliberately absent from rightWidgets in ./bar.nix: the panel
            # instantiates them itself, so a member left on the bar too would be
            # rendered twice. systemTray resolves against the plugin's built-in
            # component table, the other two through PluginService.
            targets = [
              "ambientSound"
              "systemTray"
              "usbManager"
            ];
            icon = "widgets";
            display = "icon"; # no text label beside the icon
            showChevron = true;
          };
        };
        # LuckShiba/DmsDockerManager, via dms-plugin-registry. The status half
        # of the Windows VM controls: running/stopped, ports, logs, stop and
        # restart. It cannot *start* the VM — NixOS runs oci-containers with
        # `--rm`, so a stopped container no longer exists for the plugin's start
        # button to act on. Start lives in the dankMenu `windows` subtree below.
        # LuckShiba/DmsDockerManager, deliberately left off. Its only surface is
        # a dankbar widget, and the bar is not where this belongs: the VM is
        # off most of the time, so a permanent widget spends its life showing
        # nothing. The Windows submenu below carries the status line instead,
        # where it is read at the moment it is wanted. Re-enable here and add
        # the id to rightWidgets in ./bar.nix if the general Docker view (all
        # containers, compose projects, logs, shells) ever becomes useful.
        dockerManager.enable = false;
        ambientSound.enable = true; # hthienloc/dms-ambient-sound (bar widget — no control-center variant)
        dankBatteryAlerts.enable = true; # AvengeMedia DankBatteryAlerts
        # notsopreety/batteryOSD. Used to need its own flake input, back when it
        # was missing from dms-plugin-registry; the registry has since adopted
        # it (plugins/notsopreety-batteryOSD.json), so this is a plain `enable`
        # again and the input is gone. Nothing local is layered on top of this
        # one and it is somebody else's plugin, so there is no reason to carry
        # a second pin for it — unlike dankMenu/mouthGuard above.
        # (Its sibling kbdBacklightOSD was tried too, but this laptop has no
        # kernel-visible keyboard backlight — no /sys/class/leds/*kbd_backlight*
        # node, no UPower KbdBacklight D-Bus object — so that plugin was inert
        # and got dropped.)
        batteryOSD.enable = true;
        # arcatva/dms-battery-plus, via dms-plugin-registry. Bar widget with a
        # charge-history popout plus the power-profile switcher; needs upower,
        # already on in ./default.nix. It sits at the far right of the bar
        # (../dms/bar.nix) and is why the control-center pill no longer draws a
        # battery icon of its own — two battery readouts side by side.
        batteryPlus.enable = true;
      };

      # write plugin_settings.json marking each enabled plugin active, so they
      # actually turn on (not just install). NB: makes plugin settings
      # HM-managed/read-only — set a plugin's options via plugins.<id>.settings
      # rather than the DMS UI.
      programs.dank-material-shell.managePluginSettings = true;

      # virtualKeyboard's Ydotool.qml spawns `ydotool key ...`, which reads
      # YDOTOOL_SOCKET to find ydotoold's socket (see the system service
      # above). List-valued options merge across modules, so this adds to
      # rather than replaces default.nix's Environment entries for the same
      # unit.
      systemd.user.services.dms.Service.Environment = [
        "YDOTOOL_SOCKET=/run/ydotoold.socket"
      ];

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
