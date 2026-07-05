{ pkgs, ... }:
{
  security.rtkit.enable = true;
  security.polkit.enable = true;

  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;

  # gnupg agent for GPG-signed commits etc.
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  environment.systemPackages = with pkgs; [
    polkit_gnome
  ];
}
