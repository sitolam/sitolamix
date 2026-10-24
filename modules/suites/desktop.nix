{ config, lib, ... }:
let
  cfg = config.suites.desktop;
in
{
  options.suites.desktop.enable = lib.mkEnableOption "niri + Dux Shell + wallpaper theming + kanata desktop";

  config = lib.mkIf cfg.enable {
    desktop = {
      niri.enable = true;
      dux-shell.enable = true;
      greetd.enable = true;
      kanata.enable = true;
    };
    apps = {
      # keyboard-shortcut trainer, drilled against niri's own binds
      keydrill.enable = true;
      # screen-time tracking for the desktop; the browser half of it is the
      # StayFree extension in apps.helium.
      stayfree.enable = true;
      localsend.enable = true; # LAN AirDrop-alike — GUI only, no keybind/menu row
      # On trial next to Nautilus; flip preferred once it has earned Mod+E.
      dux-files = {
        enable = true;
        preferred = false;
      };
    };
    theming.matugen.enable = true;
    services.kde-connect.enable = true;
  };
}
