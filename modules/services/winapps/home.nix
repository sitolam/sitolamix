{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.winapps;

  winappsPkg = inputs.winapps.packages.${pkgs.stdenv.hostPlatform.system}.winapps;

  appIds = cfg.apps;

  # Flag file for the on-demand toggle. State, not config, flipped from the
  # menu at runtime — presence means enabled.
  autoFlag = "/home/otis/.local/state/winapps/on-demand";

  # One file per live FreeRDP session (src/bin/winapps:75); absence is how
  # the idle watcher knows nothing is open.
  procGlob = "/home/otis/.local/share/winapps/FreeRDP_Process_*.cproc";

  # Every launcher goes through this rather than calling `winapps` directly.
  # On-demand off: pass-through. On: starts the VM first, waits for RDP.
  winapps-run = pkgs.writeShellScriptBin "winapps-run" ''
    set -u

    if [ -e ${autoFlag} ] && ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-windows; then
      ${pkgs.libnotify}/bin/notify-send --urgency=low --app-name="Windows" --icon=computer \
        "Starting Windows" "The VM is off. $1 will open once it is up."

      if ! ${pkgs.systemd}/bin/systemctl start docker-windows; then
        ${pkgs.libnotify}/bin/notify-send --app-name="Windows" --icon=dialog-error \
          --urgency=critical "Windows failed to start" "See: journalctl -u docker-windows"
        exit 1
      fi

      # Wait until the guest can actually *run* a RemoteApp: a bare TCP/auth
      # probe connects too early and wedges Windows 11's one RDP session,
      # hanging every later attempt. Probe with a real RemoteApp instead, capped per try.
      # shellcheck source=/dev/null
      . /home/otis/.config/winapps/winapps.conf
      probe="''${XDG_RUNTIME_DIR:-/tmp}/winapps-probe"
      ${pkgs.coreutils}/bin/mkdir -p "$probe"
      ${pkgs.coreutils}/bin/rm -f "$probe/ready"

      waited=0
      until [ -e "$probe/ready" ]; do
        # Under Xvfb, not the real display: FreeRDP's "RemoteApp Marker
        # Window" would otherwise appear and steal keyboard focus on niri.
        ${pkgs.xvfb-run}/bin/xvfb-run -a \
          ${pkgs.coreutils}/bin/timeout 20 ${pkgs.freerdp}/bin/xfreerdp \
          /v:127.0.0.1:3389 /u:"$RDP_USER" /p:"$RDP_PASS" /cert:ignore \
          /drive:probe,"$probe" \
          "/app:program:C:\\Windows\\System32\\cmd.exe,cmd:/c echo ok > \\\\tsclient\\probe\\ready" \
          >/dev/null 2>&1 || true

        [ -e "$probe/ready" ] && break

        sleep 5
        # One attempt plus pause; the ceiling is generous since first boot installs the OS.
        waited=$((waited + 25))
        if [ "$waited" -ge 300 ]; then
          ${pkgs.libnotify}/bin/notify-send --app-name="Windows" --icon=dialog-error \
            --urgency=critical "Windows did not come up" \
            "No RemoteApp after 5 minutes. Watch it at http://127.0.0.1:8006"
          exit 1
        fi
      done
      ${pkgs.coreutils}/bin/rm -f "$probe/ready"
    fi

    exec ${winappsPkg}/bin/winapps "$@"
  '';

  # The toggle behind the dankMenu row; `status` is what the menu's `checked` snippet calls.
  winapps-on-demand = pkgs.writeShellScriptBin "winapps-on-demand" ''
    set -u
    flag=${autoFlag}

    case "''${1:-status}" in
      status) [ -e "$flag" ] ;;
      on)
        ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$flag")"
        ${pkgs.coreutils}/bin/touch "$flag"
        ${pkgs.libnotify}/bin/notify-send --urgency=low --app-name="Windows" --icon=computer \
          "On-demand enabled" "The VM starts when you open an app and stops after ${toString cfg.idleTimeout} min idle."
        ;;
      off)
        ${pkgs.coreutils}/bin/rm -f "$flag"
        ${pkgs.libnotify}/bin/notify-send --urgency=low --app-name="Windows" --icon=computer \
          "On-demand disabled" "Start and stop the VM yourself from the Windows menu."
        ;;
      toggle)
        if [ -e "$flag" ]; then exec "$0" off; else exec "$0" on; fi
        ;;
      *)
        echo "usage: winapps-on-demand [status|on|off|toggle]" >&2
        exit 2
        ;;
    esac
  '';

  # Run on a timer. Stops the VM once no RemoteApp session has been open for
  # `idleTimeout` minutes. Ticks are counted in a file rather than a
  # timestamp so the count stays honest across suspend.
  winapps-idle-stop = pkgs.writeShellScriptBin "winapps-idle-stop" ''
    set -u
    counter=/home/otis/.local/state/winapps/idle-ticks
    ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$counter")"

    # Only acts when on-demand is on: a VM started by hand is stopped by hand.
    if [ ! -e ${autoFlag} ] || ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-windows; then
      ${pkgs.coreutils}/bin/rm -f "$counter"
      exit 0
    fi

    # A stale .cproc from a crashed FreeRDP would pin the VM on forever, so
    # check the pid is actually alive.
    live=0
    for f in ${procGlob}; do
      [ -e "$f" ] || continue
      pid=''${f##*FreeRDP_Process_}
      pid=''${pid%.cproc}
      if ${pkgs.coreutils}/bin/kill -0 "$pid" 2>/dev/null; then
        live=1
      else
        ${pkgs.coreutils}/bin/rm -f "$f"
      fi
    done

    if [ "$live" -eq 1 ]; then
      ${pkgs.coreutils}/bin/rm -f "$counter"
      exit 0
    fi

    ticks=$(${pkgs.coreutils}/bin/cat "$counter" 2>/dev/null || echo 0)
    ticks=$((ticks + 1))
    echo "$ticks" > "$counter"

    if [ "$ticks" -ge ${toString cfg.idleTimeout} ]; then
      ${pkgs.libnotify}/bin/notify-send --urgency=low --app-name="Windows" --icon=computer \
        "Stopping Windows" "Idle for ${toString cfg.idleTimeout} minutes."
      ${pkgs.systemd}/bin/systemctl stop docker-windows
      ${pkgs.coreutils}/bin/rm -f "$counter"
    fi
  '';

  # What the menu's start/stop row calls; low-urgency so it never interrupts fullscreen.
  winapps-vm = pkgs.writeShellScriptBin "winapps-vm" ''
    set -u
    notify() {
      ${pkgs.libnotify}/bin/notify-send --urgency=low --app-name="Windows" \
        --icon=computer "$1" "$2"
    }

    case "''${1:-}" in
      start)
        notify "Starting Windows" "The VM is booting."
        if ${pkgs.systemd}/bin/systemctl start docker-windows; then
          notify "Windows is up" "Office apps will open now."
        else
          ${pkgs.libnotify}/bin/notify-send --urgency=critical --app-name="Windows" \
            --icon=dialog-error "Windows failed to start" \
            "See: journalctl -u docker-windows"
          exit 1
        fi
        ;;
      stop)
        notify "Stopping Windows" "Giving it time to shut down cleanly."
        ${pkgs.systemd}/bin/systemctl stop docker-windows
        notify "Windows is off" ""
        ;;
      *)
        echo "usage: winapps-vm [start|stop]" >&2
        exit 2
        ;;
    esac
  '';

  # One line for the menu's `labelCmd`, e.g. "Running · CPU 4% · RAM 2.1GiB".
  # Reads the container's cgroup directly instead of `docker stats
  # --no-stream` (~1.1s, would make the menu row settle late) — same
  # two-sample approach at 200ms, ~250ms total. `docker stats` is the
  # fallback for cgroup layouts this doesn't find (rootless, cgroup v1, ...).
  winapps-status = pkgs.writeShellScriptBin "winapps-status" ''
    set -u

    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-windows; then
      echo "Stopped"
      exit 0
    fi

    # Up, but not answering yet — during boot, or while being torn down.
    starting_up() {
      echo "Running  ·  starting up"
      exit 0
    }

    # Only reached when the cgroup isn't where this expects it (~1.1s).
    slow_path() {
      stats=$(${pkgs.docker}/bin/docker stats --no-stream \
        --format '{{.CPUPerc}}\t{{.MemUsage}}' windows 2>/dev/null) || stats=""
      [ -n "$stats" ] || starting_up

      cpu=''${stats%%	*}
      mem=''${stats#*	}
      # docker's "used / limit" is misleading here: no limit is set, so that
      # half is just the host's total RAM. Keep the used half only.
      mem=''${mem%% /*}
      echo "Running  ·  CPU $cpu  ·  RAM $mem"
      exit 0
    }

    cid=$(${pkgs.docker}/bin/docker inspect -f '{{.Id}}' windows 2>/dev/null) || cid=""
    [ -n "$cid" ] || starting_up

    cg=/sys/fs/cgroup/system.slice/docker-$cid.scope
    [ -r "$cg/cpu.stat" ] && [ -r "$cg/memory.current" ] || slow_path

    read_cpu() {
      ${pkgs.gawk}/bin/awk '$1 == "usage_usec" { print $2 }' "$cg/cpu.stat"
    }

    t0=$EPOCHREALTIME
    c0=$(read_cpu)
    sleep 0.2
    t1=$EPOCHREALTIME
    c1=$(read_cpu)

    [ -n "$c0" ] && [ -n "$c1" ] || slow_path

    mem=$(cat "$cg/memory.current")
    # memory.current counts page cache the kernel would drop under pressure;
    # subtract the inactive part like docker does (absent on an older kernel,
    # the raw figure is close enough).
    inactive=$(${pkgs.gawk}/bin/awk '$1 == "inactive_file" { print $2 }' "$cg/memory.stat" 2>/dev/null)

    ${pkgs.gawk}/bin/awk -v c0="$c0" -v c1="$c1" -v t0="$t0" -v t1="$t1" \
      -v mem="$mem" -v inactive="$inactive" '
      BEGIN {
        elapsed = (t1 - t0) * 1000000
        cpu = elapsed > 0 ? (c1 - c0) / elapsed * 100 : 0
        if (cpu < 0) cpu = 0

        used = mem - (inactive == "" ? 0 : inactive)
        if (used < 0) used = 0
        gib = used / 1073741824
        ram = gib >= 1 ? sprintf("%.3fGiB", gib) : sprintf("%.1fMiB", used / 1048576)

        printf "Running  ·  CPU %.2f%%  ·  RAM %s\n", cpu, ram
      }'
  '';

  # WinApps ships one directory per app with an `info` file. Reading it at
  # build time (unlike upstream's install-time VM probe) means launchers
  # exist whether or not the VM has booted, and a bad app id fails the build.
  desktopEntries = pkgs.runCommand "winapps-desktop-entries" { } ''
    mkdir -p "$out"

    for id in ${lib.escapeShellArgs appIds}; do
      info="${winappsPkg}/src/apps/$id/info"
      if [ ! -f "$info" ]; then
        echo "winapps: no such application id '$id'" >&2
        echo "available:" >&2
        ls "${winappsPkg}/src/apps" >&2
        exit 1
      fi

      NAME=""; FULL_NAME=""; CATEGORIES=""; MIME_TYPES=""
      # shellcheck disable=SC1090
      . "$info"

      {
        echo "[Desktop Entry]"
        echo "Type=Application"
        echo "Name=$NAME"
        echo "Comment=$FULL_NAME"
        echo "Exec=${winapps-run}/bin/winapps-run $id %f"
        echo "Icon=${winappsPkg}/src/apps/$id/icon.svg"
        echo "Terminal=false"
        # FreeRDP names the RemoteApp window's class after this, letting niri match it.
        echo "StartupWMClass=$FULL_NAME"
        # winapps only reads its second argument, so %f — %F would silently drop all but the first file.
        echo "Categories=''${CATEGORIES:-WinApps};"
        echo "MimeType=''${MIME_TYPES:-}"
      } > "$out/$id.desktop"
    done

    # The full remote desktop, for the rare thing with no launcher of its own.
    {
      echo "[Desktop Entry]"
      echo "Type=Application"
      echo "Name=Windows"
      echo "Comment=Full Windows desktop over RDP"
      echo "Exec=${winapps-run}/bin/winapps-run windows"
      echo "Icon=${winappsPkg}/src/install/windows.svg"
      echo "Terminal=false"
      echo "StartupWMClass=Microsoft Windows"
      echo "Categories=System;WinApps;"
    } > "$out/windows.desktop"
  '';

  # winapps.conf carries the RDP password, so it can't be a store file.
  # Written at activation as root, then handed to the user 0600 — a *system*
  # activation script so it can be ordered after sops-nix's `setupSecrets`.
  writeConf = pkgs.writeShellScript "winapps-write-conf" ''
    set -eu
    # Without this, `cat >` below inherits activation's umask 0022 and briefly
    # creates winapps.conf world-readable before the chmod lands — and if
    # chown then fails, `set -eu` leaves that plaintext password exposed.
    umask 077
    secret=${config.sops.secrets.winapps_vm_env.path}
    dir=/home/otis/.config/winapps
    conf="$dir/winapps.conf"

    user=$(${pkgs.gnused}/bin/sed -n 's/^USERNAME=//p' "$secret")
    pass=$(${pkgs.gnused}/bin/sed -n 's/^PASSWORD=//p' "$secret")

    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    ${pkgs.coreutils}/bin/cat > "$conf" <<EOF
    RDP_USER="$user"
    RDP_PASS="$pass"
    RDP_DOMAIN=""
    RDP_IP="127.0.0.1"
    RDP_SCALE=${toString cfg.rdpScale}
    WAFLAVOR="manual"
    AUTOPAUSE="off"
    DEBUG="false"
    RDP_FLAGS="${lib.concatStringsSep " " cfg.rdpFlags}"
    EOF

    ${pkgs.coreutils}/bin/chown otis:users "$dir" "$conf"
    ${pkgs.coreutils}/bin/chmod 0700 "$dir"
    ${pkgs.coreutils}/bin/chmod 0600 "$conf"
  '';
in
{
  config = lib.mkIf cfg.enable {
    system.activationScripts.winappsConf = {
      deps = [ "setupSecrets" ];
      text = "${writeConf}";
    };

    home.extraOptions = {
      home.packages = [
        winappsPkg
        winapps-run
        winapps-on-demand
        winapps-vm
        winapps-status
      ];

      # Ticks once a minute; `idleTimeout` counts those ticks. Exits
      # immediately when on-demand is off or the VM is down.
      systemd.user.services.winapps-idle-stop = {
        Unit.Description = "Stop the Windows VM when no RemoteApp session is open";
        Service = {
          Type = "oneshot";
          ExecStart = "${winapps-idle-stop}/bin/winapps-idle-stop";
        };
      };

      systemd.user.timers.winapps-idle-stop = {
        Unit.Description = "Idle check for the Windows VM";
        Timer = {
          OnBootSec = "2min";
          OnUnitActiveSec = "1min";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      xdg.dataFile =
        lib.listToAttrs (
          map (
            id:
            lib.nameValuePair "applications/winapps-${id}.desktop" {
              source = "${desktopEntries}/${id}.desktop";
            }
          ) (appIds ++ [ "windows" ])
        )
        // {
          # `winapps <id>` looks for the app definition here; the package's
          # own copy under src/apps isn't on any path the launcher searches.
          "winapps/apps".source = "${winappsPkg}/src/apps";
        };
    };
  };
}
