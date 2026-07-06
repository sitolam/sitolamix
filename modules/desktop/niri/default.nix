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

  # niri tweaks live under startup.nix (niri_tile_to_n.py auto-tiler) and
  # bindings.nix (niri-scratchpad-rs). TODO: consider MintyDoggo/miri later
  # (https://github.com/MintyDoggo/miri) as an alternative tweak layer.

  options.desktop.niri.enable = lib.mkEnableOption "niri scrollable Wayland compositor";

  config = lib.mkIf cfg.enable {
    programs.niri = {
      enable = true;
      package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
    };

    # tools for the region-screenshot / OCR / color-pick keybinds, plus:
    #  - python3: runs the niri_tile_to_n.py auto-tiler (see startup.nix)
    #  - niri-scratchpad: the Mod+M/Mod+S scratchpad binary (see bindings.nix)
    environment.systemPackages = with pkgs; [
      grim
      slurp
      wl-clipboard
      tesseract
      hyprpicker
      python3
      inputs.niri-scratchpad.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # login manager lives in modules/desktop/greetd.nix (greetd + ReGreet)

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
