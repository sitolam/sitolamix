{ modulesPath, lib, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Disk layout — LUKS2 with LVM inside it, unlike gamingpc's bare ext4:
  #
  #   nvme0n1p1  NIXBOOT   vfat ESP, /boot, *unencrypted*
  #   nvme0n1p2  NIXCRYPT  LUKS2
  #              └─ vg0    LVM
  #                 ├─ swap  32G  (= RAM, so hibernate has somewhere to land)
  #                 └─ root  rest, ext4
  #
  # It's a laptop, so it gets encrypted and the desktop doesn't. The concrete
  # reason beyond the obvious: modules/system/sops.nix decrypts secrets with
  # /etc/ssh/ssh_host_ed25519_key, which on a plain disk is readable by anyone
  # who walks off with the machine.
  #
  # /boot stays outside the LUKS container, so GRUB never has to read an
  # encrypted volume (no enableCryptodisk, no second passphrase prompt) — it
  # loads the kernel and initrd, and the initrd asks for the passphrase.
  # Stage 1 is systemd-based (nixpkgs defaults boot.initrd.systemd.enable to
  # true), so the unlock is a generated /etc/crypttab entry and LVM activation
  # comes from boot.initrd.services.lvm.enable, which that same default turns
  # on. Nothing extra to declare for luks→lvm.
  boot = {
    initrd = {
      # `vmd` is the one that matters on this machine: HP ships Intel RST (VMD)
      # enabled in firmware, which hides the NVMe from the installer entirely.
      # Switching the BIOS storage mode to AHCI is the better fix — this is the
      # belt, so a system installed in RST mode still boots.
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
        # The LUKS container has no filesystem label of its own, so this is the
        # GPT *partition* name, set by `parted -- mkpart NIXCRYPT`.
        device = "/dev/disk/by-partlabel/NIXCRYPT";
        # Pass TRIM through to the SSD. The tradeoff is the standard one: it
        # leaks which blocks are unused. Worth it to keep the drive from
        # degrading.
        allowDiscards = true;
      };
    };

    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];

    # Required, and easy to miss: the *scripted* stage 1 used to sniff the
    # resume device out of swapDevices by itself, but systemd stage 1 only
    # passes `resume=` to the kernel when boot.resumeDevice is set explicitly
    # (systemd/initrd.nix). Leave it empty and hibernate silently half-works —
    # the image gets written, then the next boot ignores it and starts cold.
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

  # Inside the LUKS container, so no randomEncryption — a random per-boot key
  # would make the hibernate image unreadable on resume.
  swapDevices = [
    { device = "/dev/vg0/swap"; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  # microcode comes from nixos-hardware's common-cpu-intel, which keys it off
  # enableRedistributableFirmware — also what the Intel BE-series wifi needs.
  hardware.enableRedistributableFirmware = true;
}
