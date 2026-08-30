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

  # Flag file for the on-demand toggle. State rather than config: it is flipped
  # from the menu at runtime, so it cannot live in the Nix store. Its *presence*
  # means enabled — a flag file has no third "file exists but says garbage"
  # state to handle.
  autoFlag = "/home/otis/.local/state/winapps/on-demand";

  # Where WinApps drops one file per live FreeRDP session (src/bin/winapps:75).
  # Their absence is how the idle watcher knows nothing is open.
  procGlob = "/home/otis/.local/share/winapps/FreeRDP_Process_*.cproc";

  # ── winapps-run ───────────────────────────────────────────────────────────
  # Every launcher goes through this rather than calling `winapps` directly.
  # With on-demand off it is a straight pass-through; with it on, it starts the
  # VM first and waits for RDP to answer.
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

      # Wait until the guest can actually *run* a RemoteApp. Nothing cheaper is
      # a real readiness signal, and connecting early does not merely fail:
      #
      #   - Docker publishes 3389 the instant the container starts, so a TCP
      #     probe answers about a second in, before QEMU has booted anything.
      #   - Authentication starts working roughly 80 seconds before RemoteApp
      #     launches do (measured: `/auth-only` at +11s, a RemoteApp that runs
      #     and returns at +97s).
      #   - A connection made in that gap wedges the session. Windows 11 client
      #     editions have exactly one, so every later connection joins the
      #     wedged one and hangs too — including the ones a user makes by
      #     clicking the launcher again — until the first client gives up. That
      #     is the "it said it was starting and then nothing ever opened".
      #
      # So the gate is the thing we need: a RemoteApp that runs `echo` into a
      # redirected drive. Each attempt is capped, and a capped attempt takes
      # its own half-built session down with it, so probing too early costs
      # twenty seconds instead of poisoning everything after it.
      #
      # shellcheck source=/dev/null
      . /home/otis/.config/winapps/winapps.conf
      probe="''${XDG_RUNTIME_DIR:-/tmp}/winapps-probe"
      ${pkgs.coreutils}/bin/mkdir -p "$probe"
      ${pkgs.coreutils}/bin/rm -f "$probe/ready"

      waited=0
      until [ -e "$probe/ready" ]; do
        # Under Xvfb, not the real display: FreeRDP maps a "RemoteApp Marker
        # Window" for every RAIL connection, and on niri that window appears
        # and takes focus. Harmless but it steals your keyboard mid-typing,
        # once per probe attempt, while you wait for the app you asked for.
        ${pkgs.xvfb-run}/bin/xvfb-run -a \
          ${pkgs.coreutils}/bin/timeout 20 ${pkgs.freerdp}/bin/xfreerdp \
          /v:127.0.0.1:3389 /u:"$RDP_USER" /p:"$RDP_PASS" /cert:ignore \
          /drive:probe,"$probe" \
          "/app:program:C:\\Windows\\System32\\cmd.exe,cmd:/c echo ok > \\\\tsclient\\probe\\ready" \
          >/dev/null 2>&1 || true

        [ -e "$probe/ready" ] && break

        sleep 5
        # One attempt plus its pause; the ceiling is generous because the very
        # first boot installs the OS.
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

  # ── winapps-on-demand ─────────────────────────────────────────────────────
  # The toggle behind the dankMenu row. `status` is what the menu's `checked`
  # snippet calls.
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

  # ── winapps-idle-stop ─────────────────────────────────────────────────────
  # Run on a timer. Stops the VM once no RemoteApp session has been open for
  # `idleTimeout` minutes.
  #
  # Counting consecutive idle ticks in a file, rather than reading an uptime or
  # a last-used timestamp, keeps this honest across suspend: the count only
  # advances when the timer actually fires, so a laptop asleep for three hours
  # does not wake up and immediately kill a VM you were using.
  winapps-idle-stop = pkgs.writeShellScriptBin "winapps-idle-stop" ''
    set -u
    counter=/home/otis/.local/state/winapps/idle-ticks
    ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$counter")"

    # Only ever acts when on-demand is on: if you started the VM by hand, it is
    # yours to stop by hand.
    if [ ! -e ${autoFlag} ] || ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-windows; then
      ${pkgs.coreutils}/bin/rm -f "$counter"
      exit 0
    fi

    # A stale .cproc from a crashed FreeRDP would pin the VM on forever, so
    # check the pid is really alive rather than trusting the file's existence.
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

  # ── winapps-vm ────────────────────────────────────────────────────────────
  # What the menu's single start/stop row calls. Exists so that a manual
  # start or stop announces itself the same way an on-demand one does —
  # otherwise the VM coming up would be silent when you asked for it and noisy
  # when it asked itself.
  #
  # All notifications here are low urgency on purpose: this is status, not
  # something needing a decision, and it should never interrupt a fullscreen
  # window or survive in a do-not-disturb queue.
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

  # ── winapps-status ────────────────────────────────────────────────────────
  # One line for the menu's `labelCmd`. Reads "Stopped", or
  # "Running  ·  CPU 4%  ·  RAM 2.1GiB / 4GiB" when it is up.
  #
  # `docker stats --no-stream` is a single sample rather than a stream, which is
  # what a menu row wants — but it still costs a moment, so it only runs when
  # the VM is actually up.
  winapps-status = pkgs.writeShellScriptBin "winapps-status" ''
    set -u

    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-windows; then
      echo "Stopped"
      exit 0
    fi

    stats=$(${pkgs.docker}/bin/docker stats --no-stream \
      --format '{{.CPUPerc}}\t{{.MemUsage}}' windows 2>/dev/null) || stats=""

    if [ -z "$stats" ]; then
      # Up, but the container is not answering yet — during boot, or while it
      # is being torn down.
      echo "Running  ·  starting up"
      exit 0
    fi

    cpu=''${stats%%	*}
    mem=''${stats#*	}
    # docker reports MemUsage as "used / limit", but no memory limit is set on
    # this container, so the limit half is the host's total RAM — nothing to do
    # with the VM's own RAM_SIZE, and actively misleading next to it. Keep the
    # used half only.
    mem=''${mem%% /*}
    echo "Running  ·  CPU $cpu  ·  RAM $mem"
  '';

  # WinApps ships one directory per supported application, each with an `info`
  # file (a shell fragment defining NAME, FULL_NAME, WIN_EXECUTABLE, CATEGORIES,
  # MIME_TYPES). Upstream's setup.sh reads those at *install* time, probing a
  # running VM and writing into ~/.local behind home-manager's back. Reading
  # them at *build* time instead means the launchers exist after a rebuild
  # whether or not the VM has ever booted, and a bad app id fails the build
  # rather than producing a launcher that silently does nothing.
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
        # FreeRDP sets the RemoteApp window's class from the Windows-side
        # application name, so this is what lets niri match the window to this
        # entry (and what makes the taskbar icon correct).
        echo "StartupWMClass=$FULL_NAME"
        # winapps only ever reads its second argument, so %f (one file) rather
        # than %F (a list) — opening several files at once would silently drop
        # all but the first.
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

  # winapps.conf is a plain shell file the launcher sources, and it has to carry
  # the RDP password — so it cannot be a store file. Written at activation
  # instead, as root (which can read the sops secret regardless of owner), then
  # handed to the user 0600.
  #
  # This runs as a *system* activation script rather than a home-manager one so
  # it can be ordered after sops-nix's `setupSecrets`; home-manager activation
  # has no such ordering guarantee, and on a fresh boot would read a secret that
  # is not decrypted yet.
  writeConf = pkgs.writeShellScript "winapps-write-conf" ''
    set -eu
    # NixOS activation runs under umask 0022, which is inherited here. Without
    # this, `cat >` below would create winapps.conf mode 0644 (world-readable,
    # root-owned) for the brief window before the explicit chmod/chown land —
    # and if chown fails, `set -eu` aborts and leaves that world-readable
    # plaintext-password file behind for good. Do not delete this as
    # "redundant" with the chmod calls below: it is what makes them race-free.
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

      # Ticks once a minute; `idleTimeout` counts those ticks, so the unit of
      # the option is simply "minutes of idle". The service exits immediately
      # when on-demand is off or the VM is down, so this is close to free.
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
          # Required, not decorative: `winapps <id>` looks for the app
          # definition here. The package keeps its copy under src/apps, which is
          # not on any path the launcher searches. See src/bin/winapps:841-852.
          "winapps/apps".source = "${winappsPkg}/src/apps";
        };
    };
  };
}
