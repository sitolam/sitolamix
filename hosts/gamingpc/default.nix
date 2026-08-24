{ inputs, ... }:
{
  imports = [
    ./hardware.nix
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  networking.hostName = "gamingpc";
  system.stateVersion = "25.11";

  # hardware
  hardware.nvidia.enable = true;

  # amd_pstate: was in modules/system/boot/kernel.nix, which every host imports.
  # Moved here when omnibook (Intel) joined — it is a CPU-specific param.
  boot.kernelParams = [ "amd_pstate=active" ];

  # cloud mounts — the remotes themselves are created with `rclone config`
  # (see README → Cloud mounts), only *which* ones to mount lives here.
  services.rclone = {
    enable = true;
    remotes.gdrive_personal = { };
  };

  # NAS shares (see modules/services/nas.nix). Automounted on first access, so
  # the paths exist even when the NAS is unreachable.
  services.nas = {
    enable = true;
    server = "192.168.68.148";
    shares = [
      "backup"
      "shared"
      "media"
    ];
  };

  # On-demand Windows VM for Office (see modules/services/winapps). Same VM as
  # on omnibook, given the headroom this machine has and the laptop does not.
  services.winapps = {
    enable = true;
    ram = "8G";
    cores = 6;
  };

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
