_:
{
  flake.modules.nixos.base = {
    networking.networkmanager.enable = true;
    networking.firewall.enable = true;
  };
}
