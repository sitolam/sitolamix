{ pkgs, ... }:
{
  boot.loader = {
    grub = {
      enable = true;
      devices = [ "nodev" ];
      efiSupport = true;
      useOSProber = true;
      configurationLimit = 15;
      theme = "${pkgs.catppuccin-grub}";
    };

    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };

    timeout = 5;
  };
}
