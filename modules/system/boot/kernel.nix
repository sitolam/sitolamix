# cachyos-bore was preferred but lantian cache (attic.xuyh0120.win) was 503
# during first install; falling back to linux-zen. To switch back once
# lantian is up, re-add the nix-cachyos-kernel flake input
# (github:xddxdd/nix-cachyos-kernel/release) and:
#   nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
#   boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;
#
# CPU-specific kernel params don't belong here — this file is imported into
# every host. amd_pstate=active lives in hosts/gamingpc/default.nix.
{ pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxPackages_zen;
}
