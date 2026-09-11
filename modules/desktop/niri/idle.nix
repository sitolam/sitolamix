{ config, lib, ... }:
let
  # Only omnibook has swap sized and boot.resumeDevice set for hibernation
  # (see hosts/omnibook/hardware.nix); gamingpc has no resume device, so
  # this stays plain suspend there automatically.
  hasHibernate = config.boot.resumeDevice != "";
in
{
  config = lib.mkIf config.desktop.niri.enable {
    # HM function: needs home-manager's `config` (niri package) and `pkgs`.
    home.extraOptions =
      { config, pkgs, ... }:
      let
        # swayidle runs each command via `sh -c`, and the HM module pins the
        # unit's PATH to just bash — so spell every binary out in full.
        niri = "${config.programs.niri.package}/bin/niri";
        loginctl = "${pkgs.systemd}/bin/loginctl";
        systemctl = "${pkgs.systemd}/bin/systemctl";
        dms = "${config.programs.dank-material-shell.package}/bin/dms";

        # On battery, hand off to hibernate 15 min after suspending
        # (HibernateDelaySec, hosts/omnibook/default.nix — shared with the
        # lid-close path) — never on AC, no reason to burn a
        # resume-from-hibernate while plugged in. A previous version of this
        # armed its own RTC wake timer (systemd-run --timer-property=
        # WakeSystem=true) to get idle-sleep a longer, independent delay from
        # the lid's; dropped after that turned out to be the prime suspect
        # for the omnibook's hibernation subsystem getting stuck reporting
        # unsupported (CanHibernate="na") for the rest of a boot — see
        # memory/omnibook-hibernate-cansupport-flap.md. Plain
        # suspend-then-hibernate only, same as everything else on this host.
        # `grep -q 1 .../online` is true iff any power_supply reports an
        # AC/mains source currently connected, regardless of its device name
        # (AC, ADP1, ACAD, ...).
        sleepCommand =
          if hasHibernate then
            "if grep -q 1 /sys/class/power_supply/*/online 2>/dev/null; then ${systemctl} suspend; else ${systemctl} suspend-then-hibernate; fi"
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
              # 15 min: suspend, or suspend-then-hibernate if on battery
              # (see `sleepCommand` above).
              timeout = 900;
              command = sleepCommand;
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
