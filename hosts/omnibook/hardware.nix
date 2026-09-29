{ modulesPath, lib, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # LUKS2 with LVM inside, unlike gamingpc's bare ext4: NIXBOOT (unencrypted
  # ESP) + NIXCRYPT (LUKS2) -> vg0 -> swap (32G, = RAM, for hibernate) + root.
  # Laptop, so it's encrypted — sops.nix's secrets would otherwise be
  # readable off a stolen disk. /boot stays outside LUKS so GRUB needs no
  # passphrase; the initrd asks for it instead.
  boot = {
    initrd = {
      # vmd: HP ships Intel RST (VMD) enabled in firmware, hiding the NVMe
      # from the installer. AHCI in BIOS is the real fix; this is the belt.
      availableKernelModules = [
        "vmd"
        "nvme"
        "xhci_pci"
        "thunderbolt"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ ];

      luks.devices.cryptroot = {
        # GPT partition name, set by `parted -- mkpart NIXCRYPT`.
        device = "/dev/disk/by-partlabel/NIXCRYPT";
        # TRIM leaks which blocks are unused; worth it to keep the SSD healthy.
        allowDiscards = true;
      };
    };

    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];

    # Required: systemd stage 1 only passes `resume=` when this is set
    # explicitly. Empty, and hibernate silently half-works: image written,
    # next boot ignores it and starts cold.
    resumeDevice = "/dev/vg0/swap";
  };

  fileSystems = {
    "/" = {
      device = "/dev/vg0/root";
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

  # Inside LUKS, so no randomEncryption — a random per-boot key would make
  # the hibernate image unreadable on resume.
  swapDevices = [
    { device = "/dev/vg0/swap"; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  # Also needed for the Intel BE-series wifi and common-cpu-intel's microcode.
  hardware.enableRedistributableFirmware = true;
}
