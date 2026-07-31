# cachyos-bore was preferred but lantian cache (attic.xuyh0120.win) was 503
# during first install. Falling back to linux-zen (nixpkgs, cached).
# To switch back once lantian is up, re-add the nix-cachyos-kernel flake input
# (github:xddxdd/nix-cachyos-kernel/release) and:
#   nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
#   boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;
{ pkgs, ... }:
{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [ "amd_pstate=active" ];
  };
}
