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
    # keyboard-shortcut trainer, drilled against niri's own binds
    apps.keydrill.enable = true;
    theming.stylix.enable = true;
    services.kde-connect.enable = true;
  };
}
