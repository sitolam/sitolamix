{ config, lib, ... }:
let
  # Only omnibook has swap sized and boot.resumeDevice set for hibernation
  # (see hosts/omnibook/hardware.nix); gamingpc has no resume device, so
  # this stays plain suspend there automatically.
  hasHibernate = config.boot.resumeDevice != "";

  # Name of the deferred-hibernate transient unit armed by `sleepCommand`
  # below. Shared with the polkit rule so the two can't drift apart.
  hibernateUnit = "idle-hibernate";
in
{
  config = lib.mkIf config.desktop.niri.enable {
    # `sleepCommand` below arms a *system* transient timer to bridge from
    # "suspended" to "hibernated" on its own delay (see there for why it
    # can't just use suspend-then-hibernate/HibernateDelaySec, which
    # hosts/omnibook/default.nix already spends on the lid-close path with a
    # different delay). Starting/stopping a system unit needs polkit
    # authorization, which by default prompts — wrong for something
    # swayidle fires unattended. Scope the grant to exactly
    # "${hibernateUnit}.timer" rather than a blanket allow on
    # org.freedesktop.systemd1.manage-units, which would hand wheel
    # unprompted control over every system unit (start/stop sshd,
    # networking, ...).
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "${hibernateUnit}.timer" &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';

    # HM function: needs home-manager's `config` (niri package) and `pkgs`.
    home.extraOptions =
      { config, pkgs, ... }:
      let
        # swayidle runs each command via `sh -c`, and the HM module pins the
        # unit's PATH to just bash — so spell every binary out in full.
        niri = "${config.programs.niri.package}/bin/niri";
        loginctl = "${pkgs.systemd}/bin/loginctl";
        systemctl = "${pkgs.systemd}/bin/systemctl";
        systemdRun = "${pkgs.systemd}/bin/systemd-run";
        dms = "${config.programs.dank-material-shell.package}/bin/dms";

        # Idle-sleep (lid still open) only ever plain-suspends at 15 min —
        # never suspend-then-hibernate, which would inherit
        # hosts/omnibook/default.nix's HibernateDelaySec (15 min, tuned for
        # a *closed lid*). Idle wants a much longer 120-min-total runway
        # before hibernating, and systemd has no per-invocation delay for
        # suspend-then-hibernate — one knob, not one per trigger. So, on
        # battery only, arm a one-shot transient *system* timer for the
        # remaining 105 min that WAKES the suspended machine
        # (WakeSystem=true — the same RTC-wake mechanism
        # suspend-then-hibernate itself already uses for the lid path, see
        # journalctl) and hibernates it then. If the user wakes the machine
        # first, the sleep timeout's resumeCommand below cancels it. Never
        # armed on AC: no reason to hibernate at all while plugged in.
        # `grep -q 1 .../online` is true iff any power_supply reports an
        # AC/mains source currently connected, regardless of its device name
        # (AC, ADP1, ACAD, ...).
        sleepCommand =
          if hasHibernate then
            "if grep -q 1 /sys/class/power_supply/*/online 2>/dev/null; then ${systemctl} suspend; else ${systemdRun} --unit=${hibernateUnit} --on-active=105min --timer-property=WakeSystem=true ${systemctl} hibernate; ${systemctl} suspend; fi"
          else
            "${systemctl} suspend";

        # Undo the dim step below: raise the internal panel back by the same
        # amount it was dropped. Symmetric increment/decrement, not a
        # save/restore of the absolute level — simplest thing that works,
        # though it won't land back exactly if the panel was already near
        # 0% or 100% when idling started.
        dimStep = "30";
      in
      {
        # Idle manager. Deliberately NOT DMS's built-in IdleService — swayidle is
        # shell-agnostic (plain ext-idle-notify client), so this keeps working if
        # the shell is ever swapped out for something other than DankMaterialShell.
        #
        # "Don't idle while a video plays" needs no per-app rules: niri implements
        # zwp_idle_inhibit_manager_v1, and browsers raise a Wayland idle-inhibitor
        # while playing video. niri then withholds the idle-notify swayidle waits
        # on, so the timers below simply never elapse during YouTube/etc.
        #
        # Everything here is portable:
        #   - loginctl lock-session -> logind Lock signal. DMS picks it up via its
        #     loginctlLockIntegration (on by default); any logind-aware shell will
        #     too. No dependency on `dms ipc`.
        #   - niri msg ...          -> compositor-level DPMS, not shell-specific.
        #   - systemctl suspend     -> systemd, universal.
        services.swayidle = {
          enable = true;
          # -w (added by the HM module) makes swayidle wait for each command, so
          # the before-sleep lock is actually up before the machine suspends.

          timeouts = [
            {
              # 9.5 min: dim the internal panel as a warning shot before it
              # blanks — mirrors Windows' pre-timeout dim. External/DDC
              # monitors are left alone (dimming those over I2C is slow and
              # flickery); "" targets the default device, which bindings.nix
              # already documents as the eDP panel.
              timeout = 570;
              command = "${dms} ipc call brightness decrement ${dimStep} \"\"";
              resumeCommand = "${dms} ipc call brightness increment ${dimStep} \"\"";
            }
            {
              # 10 min: blank the outputs; wake them on any activity.
              timeout = 600;
              command = "${niri} msg action power-off-monitors";
              resumeCommand = "${niri} msg action power-on-monitors";
            }
            {
              # 11 min: lock the session.
              timeout = 660;
              command = "${loginctl} lock-session";
            }
            {
              # 15 min: suspend (see `sleepCommand` above for the deferred,
              # battery-only hibernate). On resume, cancel a still-pending
              # hibernate timer so it doesn't fire later while the machine is
              # back in use — `|| true` because there's nothing to stop once
              # it has already fired (unit gone) or was never armed (AC).
              timeout = 900;
              command = sleepCommand;
              resumeCommand = lib.optionalString hasHibernate "${systemctl} stop ${hibernateUnit}.timer 2>/dev/null || true";
            }
          ];

          # Lock before suspend/hibernate so we never resume to an unlocked
          # screen (redundant if already locked by the 11-min timer — harmless).
          # New HM format: attrset keyed by event name (was a list of
          # { event; command; } — deprecated).
          events.before-sleep = "${loginctl} lock-session";
        };
      };
  };
}
