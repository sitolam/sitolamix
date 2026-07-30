{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.niri.enable {
    home.extraOptions = {
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
        # -w (added by the HM module) makes swayidle wait for each command, so the
        # before-sleep lock is actually up before the machine suspends.

        timeouts = [
          {
            # 6 min: lock the session.
            timeout = 360;
            command = "loginctl lock-session";
          }
          {
            # 10 min: blank the outputs; wake them on any activity.
            timeout = 600;
            command = "niri msg action power-off-monitors";
            resumeCommand = "niri msg action power-on-monitors";
          }
          {
            # 15 min: suspend.
            timeout = 900;
            command = "systemctl suspend";
          }
        ];

        events = [
          # Lock before suspend/hibernate so we never resume to an unlocked
          # screen (redundant if already locked by the 6-min timer — harmless).
          {
            event = "before-sleep";
            command = "loginctl lock-session";
          }
        ];
      };
    };
  };
}
