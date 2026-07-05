{ config, lib, ... }:
let
  cfg = config.desktop.greetd;
in
{
  options.desktop.greetd.enable = lib.mkEnableOption "greetd + ReGreet (stylix-themed Wayland login)";

  config = lib.mkIf cfg.enable {
    # greetd runs ReGreet inside cage; enabling both auto-wires the session.
    services.greetd.enable = true;
    programs.regreet.enable = true;
    # stylix.targets.regreet auto-themes the greeter (wallpaper background + palette).
  };
}
