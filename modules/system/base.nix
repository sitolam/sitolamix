{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nh
    nvd
    just
    git
    vim
    curl
    wget
    pciutils
    usbutils
    file
  ];
}
