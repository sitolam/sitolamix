{ config, lib, ... }:
let
  cfg = config.suites.desktop;
in
{
  options.suites.desktop.enable = lib.mkEnableOption "niri + noctalia + stylix + kanata desktop";

  config = lib.mkIf cfg.enable {
    desktop.niri.enable = true;
    desktop.noctalia.enable = true;
    desktop.greetd.enable = true;
    theming.stylix.enable = true;
    keyboard.kanata.enable = true;
  };
}
