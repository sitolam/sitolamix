{ modulesPath, lib, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-amd" ];
    extraModulePackages = [ ];
  };

  # Current disk = ext4 root. Relabel partitions with:
  #   sudo e2label /dev/nvme0n1p2 NIXROOT
  #   sudo fatlabel /dev/nvme0n1p1 NIXBOOT
  #
  # On next fresh install, switch to btrfs subvolumes:
  #   device = "/dev/disk/by-label/NIXROOT";
  #   fsType = "btrfs";
  #   options = [ "subvol=@" "compress=zstd" "noatime" ];
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXROOT";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-label/NIXBOOT";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-label/NIXSWAP"; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault true;
    enableRedistributableFirmware = true;
  };
}
