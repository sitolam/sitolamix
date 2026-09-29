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

  # The running agent is wired up in modules/desktop/niri/default.nix (which
  # also masks niri-flake's own conflicting one); the package lives here
  # since any display manager would still want a polkit agent installed.
  environment.systemPackages = with pkgs; [
    polkit_gnome
  ];
}
