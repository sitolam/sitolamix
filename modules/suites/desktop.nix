{ config, lib, ... }:
let
  cfg = config.suites.desktop;
in
{
  options.suites.desktop.enable = lib.mkEnableOption "niri + DankMaterialShell + stylix + kanata desktop";

  config = lib.mkIf cfg.enable {
    desktop = {
      niri.enable = true;
      dms.enable = true;
      greetd.enable = true;
      kanata.enable = true;
    };
    apps = {
      # keyboard-shortcut trainer, drilled against niri's own binds
      keydrill.enable = true;
      # screen-time tracking for the desktop; the browser half of it is the
      # StayFree extension in apps.helium.
      stayfree.enable = true;
    };
    theming.stylix.enable = true;
    services.kde-connect.enable = true;
  };
}
