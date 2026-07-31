{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
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
