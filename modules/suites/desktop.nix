{ config, lib, ... }:
let
  cfg = config.suites.desktop;
in
{
  options.suites.desktop.enable = lib.mkEnableOption "niri + DankMaterialShell + stylix + kanata desktop";

  config = lib.mkIf cfg.enable {
    desktop.niri.enable = true;
    # trying DankMaterialShell instead of noctalia on this branch
    desktop.dms.enable = true;
    desktop.greetd.enable = true;
    theming.stylix.enable = true;
    keyboard.kanata.enable = true;
  };
}
