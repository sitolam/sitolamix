{ config, lib, ... }:
let
  # Only omnibook has swap + boot.resumeDevice set for hibernation;
  # gamingpc has no resume device, so this stays plain suspend there.
  hasHibernate = config.boot.resumeDevice != "";
in
{
  config = lib.mkIf config.desktop.niri.enable {
    # HM function: needs home-manager's `config` (niri package) and `pkgs`.
    home.extraOptions =
      { config, pkgs, ... }:
      let
        # swayidle runs commands via `sh -c` with PATH pinned to bash —
        # spell every binary out in full.
        niri = "${config.programs.niri.package}/bin/niri";
        loginctl = "${pkgs.systemd}/bin/loginctl";
        systemctl = "${pkgs.systemd}/bin/systemctl";
        dms = "${config.programs.dank-material-shell.package}/bin/dms";

        # On battery, hand off to hibernate 15 min after suspending
        # (HibernateDelaySec); never on AC. A custom RTC wake timer left
        # CanHibernate stuck reporting unsupported — don't reintroduce one.
        # grep matches any power_supply reporting an AC/mains source.
        sleepCommand =
          if hasHibernate then
            "if grep -q 1 /sys/class/power_supply/*/online 2>/dev/null; then ${systemctl} suspend; else ${systemctl} suspend-then-hibernate; fi"
          else
            "${systemctl} suspend";

        # Undoes the dim step below by the same amount (symmetric inc/dec,
        # not an absolute save/restore, so it won't land near 0% or 100%).
        dimStep = "40";
      in
      {
        # Not DMS's built-in IdleService: swayidle is a plain
        # ext-idle-notify client, portable if the shell ever changes. No
        # per-app rule is needed for video — niri and browsers already raise
        # a Wayland idle-inhibitor while playing.
        services.swayidle = {
          enable = true;
          # -w (HM module) makes swayidle wait for each command, so the
          # before-sleep lock is up before the machine suspends.

          timeouts = [
            {
              # Dim as a warning shot before blanking. External/DDC monitors
              # stay alone (I2C dimming is slow/flickery); "" targets the
              # default eDP panel.
              timeout = 540;
              command = "${dms} ipc call brightness decrement ${dimStep} \"\"";
              resumeCommand = "${dms} ipc call brightness increment ${dimStep} \"\"";
            }
            {
              # blank the outputs; wake them on any activity.
              timeout = 600;
              command = "${niri} msg action power-off-monitors";
              resumeCommand = "${niri} msg action power-on-monitors";
            }
            {
              timeout = 660;
              command = "${loginctl} lock-session";
            }
            {
              # suspend, or suspend-then-hibernate if on battery.
              timeout = 900;
              command = sleepCommand;
            }
          ];

          # Lock before suspend/hibernate so we never resume unlocked
          # (harmless if already locked by the timer above).
          events.before-sleep = "${loginctl} lock-session";
        };
      };
  };
}
