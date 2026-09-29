{
  # Default vm.swappiness of 60 assumes swap is cheap; on this laptop swap is
  # an LVM volume inside LUKS, so every page fault back in pays decryption
  # too. 10 keeps anonymous pages resident until genuinely out of memory,
  # which is what a 31.5 GB machine should be doing.
  #
  # No zram: /dev/vg0/swap is also the hibernate resume device (see
  # hosts/omnibook/hardware.nix), and a higher-priority zram device in front
  # of it would leave less room for the hibernate image under memory pressure.
  boot.kernel.sysctl."vm.swappiness" = 10;
}
