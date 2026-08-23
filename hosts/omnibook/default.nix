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
  #
  # Core Ultra X7 358H is Panther Lake — Xe3 graphics, xe-only, no i915 path.
  # nixos-hardware has no panther-lake directory either, so these are the two
  # settings its lunar-lake module would have applied (common/gpu/intel still
  # defaults `driver` to i915, which is wrong here). The zen kernel this flake
  # pins is well past the 6.8 the xe driver asserts on.
  hardware.intelgpu = {
    driver = "xe";
    vaapiDriver = "intel-media-driver";
  };

  # 5th-gen NPU (NPU4). ivpu kernel driver upstreamed in Linux 6.13 (zen here
  # is 7.1.8), and pkgs.intel-npu-driver 1.35.0 has carried Panther Lake
  # userspace/firmware support since 1.28.0 — nixpkgs just never enabled this
  # module for us. /dev/accel/accel0 is the resulting device node.
  hardware.cpu.intel.npu.enable = true;

  # Face unlock on the IR camera. Convenience, not a second factor — read the
  # security note at the top of modules/hardware/howdy.nix. The IR device node
  # is machine-specific; set `hardware.howdy.device` here once you have found
  # it (see README → Face unlock).
  # /dev/video2 (confirmed IR: `v4l2-ctl --list-formats-ext` reports Card
  # type "HP IR Camera", GREY-only, vs video0's color MJPG/YUYV) via its
  # stable by-path symlink — bare /dev/videoN numbering isn't guaranteed
  # across boots.
  hardware.howdy = {
    enable = true;
    device = "/dev/v4l/by-path/pci-0000:00:14.0-usb-0:3:1.2-video-index0";
  };

  # 2880x1800 panel at niri output scale 1.75 (see `niri msg outputs`) makes
  # the shared 7px default (modules/desktop/stylix.nix) nearly invisible —
  # that size is logical/unscaled, so it doesn't grow with output scale.
  stylix.cursor.size = 16;

  # cloud mounts — the remotes themselves are created with `rclone config`
  # (see README → Cloud mounts), only *which* ones to mount lives here.
  services.rclone = {
    enable = true;
    remotes.gdrive_personal = { };
  };

  # On-demand Windows VM for Office (see modules/services/winapps). Not started
  # at boot by design — start it from dankMenu's Windows submenu. Defaults are
  # sized for this laptop; the VM is a real battery cost while running.
  services.winapps.enable = true;

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
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
  };
  systemd.sleep.settings.Sleep.HibernateDelaySec = "30min";
}
