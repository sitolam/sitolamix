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

  hardware.nvidia.enable = true;

  # CPU-specific: amd_pstate only applies here, not on Intel omnibook.
  boot.kernelParams = [ "amd_pstate=active" ];

  services = {
    # Remotes are created with `rclone config` (README → Cloud mounts); this
    # only says which ones to mount.
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

    # On-demand Windows VM for Office. Same VM as omnibook; more headroom here.
    winapps = {
      enable = true;
      ram = "8G";
      cores = 6;
    };

    # Home tunnel, toggled from DMS's control center.
    wireguard-laxoi.enable = true;
  };

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

  # Monitors are managed by DMS (~/.config/niri/dms/outputs.kdl). Don't
  # declare outputs here too — it would conflict with DMS's changes.
}
