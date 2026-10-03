{ inputs, ... }:
{
  imports = [
    ./hardware.nix
    # No hp-omnibook module in nixos-hardware, so this is the generic laptop stack.
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
  ];

  networking.hostName = "omnibook";
  system.stateVersion = "25.11";

  hardware = {
    # Panther Lake (Xe3) is xe-only, no i915 path; no nixos-hardware module for it yet, and common/gpu/intel defaults `driver` to i915.
    intelgpu = {
      driver = "xe";
      vaapiDriver = "intel-media-driver";
    };

    # 5th-gen NPU (NPU4); nixpkgs never enabled this for Panther Lake despite kernel/driver support. Device node: /dev/accel/accel0.
    cpu.intel.npu.enable = true;

    # Face unlock (convenience, not a second factor — see modules/hardware/gaze.nix). irDevice is usb:VID:PID since /dev/videoN numbering isn't stable. device = "npu" keeps inference cheap enough to race the password prompt.
    gaze = {
      enable = true;
      irDevice = "usb:0408:5494";
      device = "npu";
      unlockKeyring = true;
      duress.enable = true;
    };
  };

  # Xe3 display-engine bug (not misconfiguration): DSB commit stalls flood dmesg
  # with "DSB 0 poll error" and read as dropped frames. Retest after kernel
  # bumps with `journalctl -k -b | grep -c "DSB 0 poll error"`.
  boot.kernelParams = [
    "xe.enable_dsb=0"
  ];

  # 2880x1800 panel at scale 1.75 makes the shared 7px cursor default nearly
  # invisible — cursor size is logical, so it doesn't grow with output scale.
  theming.matugen.cursorSize = 16;

  services = {
    # Remote-triggerable from the paired phone. deviceId is this machine's
    # kdeconnect identity — regenerate under ~/.config/kdeconnect/ if needed.
    kde-connect = {
      deviceId = "a1064e6b61e148d4857dc698990e06e2";
      commands = {
        "Lock Screen" = "loginctl lock-session";
        "Suspend" = "systemctl suspend";
      };
    };

    # Remotes are created with `rclone config`; this only says which to mount.
    rclone = {
      enable = true;
      remotes.gdrive_personal = { };
    };

    # Automounted on first access, so the paths exist even when unreachable.
    nas = {
      enable = true;
      server = "192.168.68.148";
      shares = [
        "backup"
        "shared"
        "media"
      ];
    };

    # On-demand Windows VM for Office. Not started at boot — start from
    # dankMenu's Windows submenu.
    winapps = {
      enable = true;
      # Pinned at 64G (installed before the default dropped to 32G); shrinking
      # means reinstalling, and the sparse image doesn't cost the difference.
      disk = "64G";
      # Matches this panel's niri scale (1.75); FreeRDP only offers 100/140/180.
      rdpScale = 180;
    };

    # Home tunnel, toggled from DMS's control center.
    wireguard-laxoi.enable = true;

    # Battery: suspend then hibernate after HibernateDelaySec. AC: plain
    # suspend, never hibernate. Laptop-only (gamingpc has no lid); the
    # idle-timer path (modules/desktop/niri/idle.nix) arms its own wake timer.
    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend";
    };
  };

  # How long a closed lid (battery only) stays suspended before hibernating.
  systemd.sleep.settings.Sleep.HibernateDelaySec = "15min";

  suites = {
    core.enable = true;
    desktop.enable = true;
    development.enable = true;
    browser.enable = true;
    media.enable = true;
    social.enable = true;
    school.enable = true;
    gaming.enable = true;
    ai.enable = true;
  };

  # Monitors are managed by DMS (~/.config/niri/dms/outputs.kdl) — don't
  # declare outputs here too.
}
