{ inputs, ... }:
{
  imports = [
    ./hardware.nix
    # No hp-omnibook module exists in nixos-hardware (only elitebook/probook/
    # laptop/notebook), so this is the generic laptop stack.
    # common-cpu-intel pulls common/gpu/intel in with it.
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
  ];

  networking.hostName = "omnibook";
  system.stateVersion = "25.11";

  # hardware
  hardware = {
    # Core Ultra X7 358H is Panther Lake — Xe3 graphics, xe-only, no i915 path.
    # nixos-hardware has no panther-lake directory either, so these are the two
    # settings its lunar-lake module would have applied (common/gpu/intel still
    # defaults `driver` to i915, which is wrong here). The zen kernel this flake
    # pins is well past the 6.8 the xe driver asserts on.
    intelgpu = {
      driver = "xe";
      vaapiDriver = "intel-media-driver";
    };

    # 5th-gen NPU (NPU4). ivpu kernel driver upstreamed in Linux 6.13 (zen here
    # is 7.1.8), and pkgs.intel-npu-driver 1.35.0 has carried Panther Lake
    # userspace/firmware support since 1.28.0 — nixpkgs just never enabled this
    # module for us. /dev/accel/accel0 is the resulting device node.
    cpu.intel.npu.enable = true;

    # Face unlock. Convenience, not a second factor — read the security note at
    # the top of modules/hardware/gaze.nix. The IR camera is machine-specific
    # (see README → Face unlock): the Quanta "HP 5MP Camera" module, whose IR
    # half is the GREY-only V4L2 node (`v4l2-ctl --list-formats-ext`) next to
    # the colour MJPG/YUYV one. Given as usb:VID:PID rather than a device node
    # so gaze resolves the infrared node itself — /dev/videoN numbering isn't
    # guaranteed across boots, and a by-path symlink is not a form gaze parses.
    #
    # device = "npu": the NPU enabled just above. Face detection and
    # recognition are exactly the small fixed-shape CNNs it exists for, and
    # keeping them off the CPU is what makes a scan that races the password
    # prompt cheap enough to run on every unlock, on battery.
    gaze = {
      enable = true;
      irDevice = "usb:0408:5494";
      device = "npu";
    };
  };

  # Xe3 display-engine workaround. The driver stack above is correct (xe +
  # iHD, both confirmed loaded); what misbehaves is Panther Lake's still-young
  # display code.
  #
  #   xe.enable_dsb=0 — Display State Buffer, the batched register-write path
  #     for atomic commits. Symptom: "[CRTC:151:pipe A] DSB 0 poll error"
  #     repeating about once per vblank (660k lines in one boot before this),
  #     which stalls commits and reads as dropped frames in video playback.
  #
  # Display-engine only — no effect on rendering or VA-API decode.
  #
  # xe.enable_psr=0 (Panel Self Refresh) used to sit here too, for half-panel
  # blackouts logged as "Timed out waiting PSR idle state", "Selective fetch
  # area calculation failed in pipe A" and "CPU pipe A FIFO underrun". Dropped
  # on 2026-08-26 to retest on zen 7.1.9 (it was set on 7.1.8), because PSR is
  # the display feature that actually costs idle battery when off. If the
  # blackouts come back, put it back; if they do not, it is fixed upstream.
  # Verify after a few hours of use, on this boot:
  #   journalctl -k -b | grep -cE "PSR idle state|Selective fetch|FIFO underrun"
  # Same one-at-a-time retest applies to DSB after the next kernel bump:
  #   journalctl -k -b | grep -c "DSB 0 poll error"
  boot.kernelParams = [
    "xe.enable_dsb=0"
  ];

  # 2880x1800 panel at niri output scale 1.75 (see `niri msg outputs`) makes
  # the shared 7px default (modules/theming/stylix.nix) nearly invisible —
  # that size is logical/unscaled, so it doesn't grow with output scale.
  stylix.cursor.size = 16;

  services = {
    # cloud mounts — the remotes themselves are created with `rclone config`
    # (see README → Cloud mounts), only *which* ones to mount lives here.
    rclone = {
      enable = true;
      remotes.gdrive_personal = { };
    };

    # NAS shares (see modules/services/nas.nix). Automounted on first access, so
    # the paths exist even when the NAS is unreachable.
    nas = {
      enable = true;
      server = "192.168.68.148";
      shares = [
        "backup"
        "shared"
        "media"
      ];
    };

    # On-demand Windows VM for Office (see modules/services/winapps). Not started
    # at boot by design — start it from dankMenu's Windows submenu. Defaults are
    # sized for this laptop; the VM is a real battery cost while running.
    winapps = {
      enable = true;
      # This machine's VM already exists at 64G (installed before the default
      # dropped to 32G). Shrinking would mean deleting stateDir/storage and
      # reinstalling Windows and Office, and the image is sparse anyway — the
      # number is a ceiling, not space consumed — so it is pinned rather than
      # migrated.
      disk = "64G";
      # This panel runs at niri output scale 1.75; without a matching RDP scale
      # Windows renders 1:1 and Office text comes out tiny next to everything
      # else. FreeRDP only offers 100/140/180.
      rdpScale = 180;
    };

    # Lid close and idle-suspend both hand off to hibernate — but only on
    # battery. On AC there's no reason to burn a resume-from-hibernate on
    # what's effectively a desktop with a lid, so that case stays plain
    # suspend. Idle-timer side (same battery/AC split) lives in
    # modules/desktop/niri/idle.nix, gated on boot.resumeDevice which only
    # this host sets. Laptop-only: gamingpc has no lid and no resume device,
    # so none of this applies there.
    #
    # suspend-then-hibernate sleeps immediately (RAM suspend, near-zero
    # latency to resume), then after HibernateDelaySec of staying suspended,
    # systemd wakes it briefly to write RAM out to swap and hibernate for
    # real — so a closed lid on battery still only costs real power for
    # 30 min before it's safe to unplug the charger entirely.
    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend";
    };
  };

  # The other half of the lid/idle handoff above: how long suspend-then-hibernate
  # stays merely suspended before writing RAM to swap.
  systemd.sleep.settings.Sleep.HibernateDelaySec = "30min";

  # feature suites
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

  # Monitors are managed by DMS (settings UI -> ~/.config/niri/dms/outputs.kdl,
  # included via desktop.dms). Don't also declare outputs here — a second
  # definition in hm.kdl conflicts and DMS's changes wouldn't apply.
}
