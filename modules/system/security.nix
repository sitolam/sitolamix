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

  # The agent that actually runs is wired up in modules/desktop/niri/default.nix
  # (which also masks niri-flake's own conflicting one); the package lives
  # here rather than there since a display manager other than niri would still
  # want a polkit agent installed.
  environment.systemPackages = with pkgs; [
    polkit_gnome
  ];
}
