# Windows Hello-style face unlock (boltgolt/howdy) off the laptop's IR camera.
#
# SECURITY: howdy is *not* the equivalent of Windows Hello. Hello does a
# depth/structured-light liveness check; howdy compares a 2D IR image and can be
# fooled by a well-printed photo or a phone screen. Upstream and the NixOS
# module both say so. It is wired here as a *convenience* only:
#
#   - control = "sufficient": a face match unlocks, a miss falls silently
#     through to the normal password prompt. Never the sole factor in practice,
#     because the password path is always still there.
#   - scoped to three PAM services (login/greetd/sudo), not all of them —
#     enabling services.howdy alone would default security.pam.howdy.enable to
#     true, which reaches every service including sshd.
#
# Want face-as-second-factor instead? Set control = "required" — then a failed
# scan *blocks* the login rather than falling back.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.howdy;
in
{
  options.hardware.howdy = {
    enable = lib.mkEnableOption "howdy face unlock on the IR camera (see the security note in this file)";

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/video2";
      example = "/dev/v4l/by-path/pci-0000:00:14.0-usb-0:8:1.0-video-index2";
      description = ''
        The *IR* camera node — not the colour one. `/dev/videoN` numbering is
        not stable across boots; prefer a `/dev/v4l/by-path/...` symlink once
        you know which device it is. Find it on the machine with:

        ```sh
        v4l2-ctl --list-devices
        # then, for each candidate, check it is the infrared one:
        howdy -U otis test
        ```
      '';
    };

    control = lib.mkOption {
      type = lib.types.str;
      default = "sufficient";
      description = ''
        PAM control flag. "sufficient" = face unlocks, miss falls back to
        password. "required" = face must succeed (true second factor, and a
        miss blocks login).
      '';
    };

    irEmitter.enable = lib.mkEnableOption ''
      linux-enable-ir-emitter. Needed only for cameras whose IR LEDs do not
      light up on their own — the image comes back black in `howdy test` even
      though the device is right. Requires a one-off
      `sudo linux-enable-ir-emitter configure` on the machine
    '';
  };

  config = lib.mkIf cfg.enable {
    services.howdy = {
      enable = true;
      inherit (cfg) control;
      settings.video = {
        device_path = cfg.device;
        # PAM runs auth modules one at a time, in stack order, synchronously —
        # howdy is listed before pam_unix (see below), so the password prompt
        # can't even appear until howdy's scan call returns. Default is 4s;
        # trimmed to cut how long typing a password is blocked on a scan that
        # isn't going to match anyway. DMS races fingerprint against password
        # as an independent, concurrent PAM context (Modules/Lock/Pam.qml,
        # `fprint`/`passwd` both `start()`, first one to `Success` wins and
        # aborts the other) — howdy has no such slot, it's just wired into
        # the same sequential stack as the password. Filed upstream:
        # https://github.com/AvengeMedia/DankMaterialShell/issues/3146
        # requesting a concurrent context like fprint's.
        timeout = 2;
      };
    };

    # Off globally, on for exactly three services. `login` is the one the DMS
    # lock screen authenticates against — DMS actually mirrors this into a
    # user-local `dankshell` PAM service at first lock (`dms auth
    # resolve-lock`, see Modules/Lock/Pam.qml), not a static PAM file of its
    # own — `greetd` is the dms-greeter login screen, `sudo` is sudo.
    security.pam.howdy.enable = false;
    security.pam.services = lib.genAttrs [ "login" "greetd" "sudo" ] (_: {
      howdy.enable = true;
    });

    services.linux-enable-ir-emitter = lib.mkIf cfg.irEmitter.enable {
      enable = true;
      device = baseNameOf cfg.device;
    };

    # Enrolled face models land here (the package's `user_models_dir` meson
    # option). Nothing in the upstream NixOS module creates the directory, so
    # `howdy add` on a fresh machine has nowhere to write.
    #
    # 0711, not 0700: `login`/`greetd`/`sudo` authenticate as root, so 0700
    # would work for those, but DMS's lock screen runs the PAM check
    # in-process as the logged-in user (no root elevation) — with 0700 it
    # can't even open the directory, howdy fails instantly with no scan
    # attempt, and every unlock silently falls through to the password
    # prompt. 0711 allows traversal to a known filename (what pam_howdy
    # needs) without directory listing; the .dat files land 0644 already.
    systemd.tmpfiles.rules = [ "d /var/lib/howdy/models 0711 root root -" ];

    # v4l-utils: `v4l2-ctl --list-devices`, to find the IR node in the first
    # place. howdy itself is installed by its own module.
    environment.systemPackages = [ pkgs.v4l-utils ];
  };
}
