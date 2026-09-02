{
  # The default vm.swappiness of 60 assumes swap is cheap. On this laptop it is
  # not: swap is an LVM volume inside LUKS, so every page fault back in pays
  # decryption on top of the read.
  #
  # Measured on 2026-09-02 while CS2 ran: 9.3 GB swapped out, `vmstat` showing
  # ~450 MB/s of block-in and 10-36% iowait with *zero* runnable threads and
  # cores parked at 1.3 GHz. The game was not CPU-bound and not GPU-bound (the
  # iGPU sat at 2400 of 2500 MHz) — it was waiting on the swap device. 10 keeps
  # anonymous pages resident until the machine is genuinely out of memory,
  # which is what a 31.5 GB machine should be doing.
  #
  # No zram here on purpose: /dev/vg0/swap is also the hibernate resume device
  # (see hosts/omnibook/hardware.nix), and a higher-priority zram device in
  # front of it would leave less of it free for the hibernate image at exactly
  # the moment memory pressure is highest.
  boot.kernel.sysctl."vm.swappiness" = 10;
}
