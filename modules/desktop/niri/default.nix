{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.desktop.niri;
in
{
  imports = [ inputs.niri.nixosModules.niri ];

  options.desktop.niri.enable = lib.mkEnableOption "niri scrollable Wayland compositor";

  config = lib.mkIf cfg.enable {
    programs.niri = {
      enable = true;
      package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
    };

    # display manager
    services.displayManager.sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      wayland.enable = true;
    };

    # xdg-portals for wayland
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
      ];
    };

    # dbus + polkit gui agent
    services.dbus.enable = true;
    systemd.user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
}
