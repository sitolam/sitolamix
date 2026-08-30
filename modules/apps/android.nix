{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.apps.android;

  addr = "${cfg.host}:${toString cfg.port}";

  # ── Resolving the phone's address ─────────────────────────────────────────
  # The phone's wireless-adb port is fixed, but its IP is a DHCP lease. Rather
  # than pin a reservation in the router, ask KDE Connect (services/kde-connect
  # .nix) — it is already paired with the phone and tracks its current address:
  #
  #   busctl --user --json=short get-property org.kde.kdeconnect \
  #     /modules/kdeconnect/devices/<id> org.kde.kdeconnect.device \
  #     reachableAddresses
  #   → {"type":"as","data":["192.168.68.166"]}
  #
  # Devices are found by walking the object tree and filtering on
  # paired+reachable+phone rather than hard-coding the device id, which would
  # break on re-pairing. Talking to D-Bus directly (not kdeconnect-cli) keeps
  # this module from depending on the kdeconnect package: when KDE Connect is
  # off, unpaired or the name is unavailable, we simply fall back to cfg.host.
  phoneAddr = pkgs.writeShellApplication {
    name = "android-phone-addr";
    # Every one of these scripts runs from a systemd *user service*, whose PATH
    # is NixOS's service default — coreutils, findutils, gnugrep, gnused,
    # systemd, and nothing else. Notably no bash and no util-linux. So each
    # runtime command has to be declared here rather than assumed from the
    # ambient PATH of an interactive shell.
    runtimeInputs = [
      pkgs.systemd # busctl
      pkgs.jq
      pkgs.gnugrep
    ];
    text = ''
      prop() { # <object-path> <property>
        busctl --user --json=short get-property org.kde.kdeconnect \
          "$1" org.kde.kdeconnect.device "$2" 2>/dev/null || true
      }

      paths=$(busctl --user tree org.kde.kdeconnect 2>/dev/null \
        | grep -oE '/modules/kdeconnect/devices/[^/[:space:]]+$' || true)

      for path in $paths; do
        [ "$(prop "$path" isPaired    | jq -r '.data // false')" = "true"  ] || continue
        [ "$(prop "$path" isReachable | jq -r '.data // false')" = "true"  ] || continue
        [ "$(prop "$path" type        | jq -r '.data // ""'   )" = "phone" ] || continue

        ip=$(prop "$path" reachableAddresses | jq -r '.data[0] // empty')
        if [ -n "$ip" ]; then
          echo "$ip:${toString cfg.port}"
          exit 0
        fi
      done

      # KDE Connect could not answer — fall back to the configured address.
      echo "${addr}"
    '';
  };

  # ── Connecting ────────────────────────────────────────────────────────────
  # Idempotent: exits 0 when the phone is usable over adb, 1 otherwise. Both
  # `screen` and the watcher go through this, so `screen` works whether or not
  # the watcher is running.
  connect = pkgs.writeShellApplication {
    name = "android-connect";
    runtimeInputs = [
      pkgs.android-tools
      phoneAddr
      # bash is for the /dev/tcp probe below and coreutils for its `timeout`.
      # Both absent from the systemd service PATH: without them the probe exited
      # 127 every cycle, which the `if !` read as "port closed", so the watcher
      # decided the phone was unreachable forever and never called adb connect.
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      target=$(android-phone-addr)

      connected() {
        # only "device" counts — an "unauthorized" phone (the RSA prompt has
        # not been accepted) or an "offline" one is not usable.
        adb devices | grep -qE "^''${target}[[:space:]]+device$"
      }

      if connected; then exit 0; fi

      # Probe first: `adb connect` to a dead host blocks for its own timeout and
      # leaves an offline entry behind.
      if ! timeout 2 bash -c "exec 3<>/dev/tcp/''${target%:*}/''${target##*:}" 2>/dev/null; then
        exit 1
      fi

      adb connect "$target" >/dev/null 2>&1 || true
      connected
    '';
  };

  # ── The notification ──────────────────────────────────────────────────────
  # notify-send -A blocks until the notification is actioned or closed, then
  # prints the action key, so this runs as its own transient unit rather than
  # inside the watcher's poll loop. Verified against DMS: it renders the button
  # and returns "show" on click.
  notify = pkgs.writeShellApplication {
    name = "android-notify-connected";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.coreutils # timeout
      screen
    ];
    text = ''
      # bounded so a notification that is never touched cannot leave this
      # process resident forever; the button stays live for 30 minutes.
      action=$(timeout 1800 notify-send \
        --app-name=android \
        --icon=phone \
        --action=show="Show screen" \
        "Phone connected" "wireless adb on $1" || true)

      [ "$action" = "show" ] && exec screen
      exit 0
    '';
  };

  # ── The launcher ──────────────────────────────────────────────────────────
  # Successor to the quickhyprnix script (`setsid scrcpy --shortcut-mod=lctrl
  # --show-touches &`), keeping those flags.
  screen = pkgs.writeShellApplication {
    name = "screen";
    runtimeInputs = [
      pkgs.scrcpy
      pkgs.jq
      pkgs.libnotify
      pkgs.systemd
      pkgs.util-linux # setsid, for the fallback launch
      config.programs.niri.package
      connect
    ];
    text = ''
      # Already mirroring? Focus that window instead of opening a second one.
      window=$(niri msg --json windows 2>/dev/null \
        | jq -r 'map(select(.app_id == "scrcpy")) | .[0].id // empty' || true)
      if [ -n "$window" ]; then
        niri msg action focus-window --id "$window"
        exit 0
      fi

      if ! android-connect; then
        notify-send --app-name=android --icon=phone \
          "Phone not reachable" \
          "no wireless adb on ${addr} — is the phone on wifi with debugging on?"
        exit 1
      fi

      mirror=(scrcpy --shortcut-mod=lctrl --keep-active)

      # A transient unit, so the mirror is owned by the user manager rather than
      # by whatever started it: closing the terminal, restarting the watcher or
      # dismissing the notification cannot take it down. --collect reaps the
      # unit when scrcpy exits, so the fixed name is free for the next run.
      #
      # The fallback is not theoretical: StartTransientUnit fails outright when
      # /run/user/$UID is full (the manager cannot write the unit file), which
      # is exactly the state this machine was in while this was written — a
      # dead quickshell instance had left a 1.6G log there. Launching the mirror
      # should not be collateral damage of that, so fall back to the plain
      # detached spawn the old quickhyprnix script used.
      if ! systemd-run --user --collect --quiet --unit=scrcpy-screen -- \
        "''${mirror[@]}" 2>/dev/null; then
        setsid "''${mirror[@]}" >/dev/null 2>&1 &
      fi
    '';
  };

  # ── The watcher ───────────────────────────────────────────────────────────
  # Polls rather than subscribing to KDE Connect's PropertiesChanged signal:
  # wireless adb can be toggled on the phone *after* it becomes reachable, so an
  # edge-triggered design still needs a retry loop. Two D-Bus reads and one TCP
  # connect every 15s is cheap, and it is one code path instead of two.
  watch = pkgs.writeShellApplication {
    name = "android-adb-watch";
    runtimeInputs = [
      pkgs.android-tools
      pkgs.systemd # systemd-run
      pkgs.coreutils # sleep
      connect
      phoneAddr
      notify
    ];
    text = ''
      connected=0

      while :; do
        if android-connect; then
          if [ "$connected" -eq 0 ]; then
            connected=1
            target=$(android-phone-addr)
            # detached so the poll loop never blocks on notify-send waiting for
            # the button; same transient-unit fallback as `screen`.
            if ! systemd-run --user --collect --quiet -- \
              android-notify-connected "$target" 2>/dev/null; then
              android-notify-connected "$target" >/dev/null 2>&1 &
            fi
          fi
        elif [ "$connected" -eq 1 ]; then
          connected=0
          # no argument: drops every *networked* device, which also cleans up a
          # stale entry when the phone came back on a different IP. USB devices
          # are untouched.
          adb disconnect >/dev/null 2>&1 || true
        fi

        sleep ${toString cfg.interval}
      done
    '';
  };
in
{
  options.apps.android = {
    enable = lib.mkEnableOption "Android tooling: adb, scrcpy, and wireless auto-connect";

    host = lib.mkOption {
      type = lib.types.str;
      default = "192.168.68.166";
      description = "Fallback phone IP, used only when KDE Connect cannot resolve one.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 1828;
      description = "Wireless adb port on the phone.";
    };

    interval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 15;
      description = "Seconds between reachability checks.";
    };

    watch.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Auto-connect to the phone and notify when it appears on the network.";
    };
  };

  config = lib.mkIf cfg.enable {
    # adb + fastboot in the system PATH. `programs.adb.enable` is gone from
    # nixpkgs (systemd 258 applies the uaccess rules for USB devices itself, so
    # the module and its adbusers group are no longer needed) — the package on
    # its own is now the whole story.
    environment.systemPackages = [ pkgs.android-tools ];

    # User service, not system: it needs the session bus for KDE Connect and for
    # notifications, and it shares the user's adb server — so a phone it
    # connects shows up in `adb devices` in any terminal.
    systemd.user.services.android-adb-watch = lib.mkIf cfg.watch.enable {
      description = "Connect to the phone's wireless adb when it appears on the network";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe watch;
        Restart = "always";
        RestartSec = 5;
        # only the poll loop is killed on stop/restart. When the transient-unit
        # fallback is in play the mirror and the pending notification are plain
        # children of this service, and restarting the watcher should not take
        # the screen you are looking at down with it.
        KillMode = "process";
      };
    };

    home.extraOptions = {
      home.packages = [
        pkgs.scrcpy
        screen # `screen` — launch or focus the mirror
        connect # `android-connect` — connect by hand
      ];

      # also reachable from DMS Spotlight (Mod+Space).
      xdg.desktopEntries.phone-screen = {
        name = "Phone Screen";
        comment = "Mirror the phone over wireless adb";
        exec = "screen";
        icon = "phone";
        terminal = false;
        categories = [ "Utility" ];
      };

      # niri bits live here rather than in niri/rules.nix + niri/bindings.nix so
      # the whole feature stays in one file; both option types merge across
      # modules.
      programs.niri.settings = lib.mkIf config.desktop.niri.enable {
        # Mod+Alt+<letter> is the "run a tool" plane — see
        # ../desktop/niri/KEYBINDINGS.md. It was Mod+Shift+A, which read as a
        # variant of Mod+A (tabbed columns) and was not one.
        binds."Mod+Alt+A".action.spawn = "screen";

        window-rules = lib.mkAfter [
          {
            # deliberately unanchored: nixpkgs wraps the binary, so the Wayland
            # app-id SDL reports is ".scrcpy-wrapped", not "scrcpy" (SDL_APP_ID
            # does not override it). This still matches if the wrapper ever goes
            # away.
            matches = [ { app-id = "scrcpy"; } ];
            open-floating = true;
            # niri/rules.nix makes every window 0.8 translucent so the global
            # blur shows; on a phone mirror that just looks broken. This rule is
            # mkAfter'd so it lands after that one — last match wins.
            opacity = 1.0;
            # height only: scrcpy sizes itself to the phone's aspect ratio.
            default-window-height.fixed = 900;
          }
        ];
      };
    };
  };
}
