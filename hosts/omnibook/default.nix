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

  # Face unlock on the IR camera. Convenience, not a second factor — read the
  # security note at the top of modules/hardware/howdy.nix. The IR device node
  # is machine-specific; set `hardware.howdy.device` here once you have found
  # it (see README → Face unlock).
  hardware.howdy.enable = true;

  # 2880x1800 panel at niri output scale 1.75 (see `niri msg outputs`) makes
  # the shared 7px default (modules/desktop/stylix.nix) nearly invisible —
  # that size is logical/unscaled, so it doesn't grow with output scale.
  stylix.cursor.size = 16;

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
