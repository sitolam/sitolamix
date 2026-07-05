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
  };

  # per-host monitors — HM niri outputs (aliased through home.extraOptions)
  home.extraOptions.programs.niri.settings.outputs = {
    "DP-3" = {
      mode = {
        width = 1920;
        height = 1080;
        refresh = 60.000;
      };
      scale = 1.0;
      position = {
        x = 0;
        y = 0;
      };
      focus-at-startup = true;
    };
    "HDMI-A-1" = {
      mode = {
        width = 1920;
        height = 1080;
        refresh = 60.000;
      };
      scale = 1.0;
      position = {
        x = 1920;
        y = 0;
      };
    };
  };
}
