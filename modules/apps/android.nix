{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.apps.android;

  addr = "${cfg.host}:${toString cfg.port}";

  # The phone's IP is a DHCP lease; ask KDE Connect over D-Bus (already
  # paired, tracks the current address) instead of a router reservation.
  # Falls back to cfg.host when KDE Connect can't answer.
  phoneAddr = pkgs.writeShellApplication {
    name = "android-phone-addr";
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

      echo "${addr}"
    '';
  };

  # Idempotent: exits 0 when the phone is usable over adb. Shared by `screen`
  # and the watcher, so `screen` works whether or not the watcher is running.
  connect = pkgs.writeShellApplication {
    name = "android-connect";
    runtimeInputs = [
      pkgs.android-tools
      phoneAddr
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      target=$(android-phone-addr)

      connected() {
        # only "device" counts, not "unauthorized" or "offline"
        adb devices | grep -qE "^''${target}[[:space:]]+device$"
      }

      if connected; then exit 0; fi

      # probe first: `adb connect` to a dead host blocks and leaves an offline entry
      if ! timeout 2 bash -c "exec 3<>/dev/tcp/''${target%:*}/''${target##*:}" 2>/dev/null; then
        exit 1
      fi

      adb connect "$target" >/dev/null 2>&1 || true
      connected
    '';
  };

  # notify-send -A blocks until actioned or closed, so this runs as its own
  # transient unit rather than in the watcher's poll loop.
  notify = pkgs.writeShellApplication {
    name = "android-notify-connected";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.coreutils # timeout
      screen
    ];
    text = ''
      # bounded so an untouched notification doesn't hold this process open forever
      action=$(timeout 1800 notify-send \
        --app-name=android \
        --icon=phone \
        --action=show="Show screen" \
        "Phone connected" "wireless adb on $1" || true)

      [ "$action" = "show" ] && exec screen
      exit 0
    '';
  };

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
      # already mirroring? focus that window instead of opening a second one
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

      # transient unit so closing the terminal or restarting the watcher can't
      # kill the mirror; falls back to a detached spawn if StartTransientUnit fails
      if ! systemd-run --user --collect --quiet --unit=scrcpy-screen -- \
        "''${mirror[@]}" 2>/dev/null; then
        setsid "''${mirror[@]}" >/dev/null 2>&1 &
      fi
    '';
  };

  # Polls rather than subscribing to KDE Connect's signal: adb can be toggled
  # on after the phone becomes reachable, so a retry loop is needed either way.
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
            # detached so the poll loop never blocks waiting on notify-send
            if ! systemd-run --user --collect --quiet -- \
              android-notify-connected "$target" 2>/dev/null; then
              android-notify-connected "$target" >/dev/null 2>&1 &
            fi
          fi
        elif [ "$connected" -eq 1 ]; then
          connected=0
          # no argument: drops every networked device, cleaning up a stale
          # entry if the phone came back on a different IP; USB is untouched
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
    # programs.adb.enable is gone from nixpkgs; systemd 258 applies the USB
    # uaccess rules itself, so the package alone is the whole story.
    environment.systemPackages = [ pkgs.android-tools ];

    # user service: needs the session bus for KDE Connect/notifications, and
    # shares the user's adb server so a connected phone shows up anywhere
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
        # only the poll loop is killed, so a restart doesn't take down a
        # running mirror or pending notification
        KillMode = "process";
      };
    };

    home.extraOptions = {
      home.packages = [
        pkgs.scrcpy
        screen
        connect
      ];

      # also reachable from DMS Spotlight (Mod+Space)
      xdg.desktopEntries.phone-screen = {
        name = "Phone Screen";
        comment = "Mirror the phone over wireless adb";
        exec = "screen";
        icon = "phone";
        terminal = false;
        categories = [ "Utility" ];
      };

      # niri bits live here, not in niri/rules.nix + niri/bindings.nix, so the
      # whole feature stays in one file; both option types merge fine.
      programs.niri.settings = lib.mkIf config.desktop.niri.enable {
        # Mod+Alt+<letter> is the "run a tool" plane
        binds."Mod+Alt+A".action.spawn = "screen";

        window-rules = lib.mkAfter [
          {
            # unanchored: nixpkgs wraps the binary, so the app-id is ".scrcpy-wrapped"
            matches = [ { app-id = "scrcpy"; } ];
            open-floating = true;
            # mkAfter'd so full opacity wins over niri/rules.nix's global 0.8 blur
            opacity = 1.0;
            default-window-height.fixed = 900; # scrcpy sizes width to the phone's aspect ratio
          }
        ];
      };
    };
  };
}
