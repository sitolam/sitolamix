{ config, lib, ... }:
let
  cfg = config.desktop.greetd;
in
{
  options.desktop.greetd.enable = lib.mkEnableOption "greetd + ReGreet (stylix-themed Wayland login)";

  config = lib.mkIf cfg.enable {
    # greetd runs ReGreet inside cage; enabling both auto-wires the session.
    services.greetd.enable = true;
    services.displayManager.regreet.enable = true; # renamed from programs.regreet
    # stylix.targets.regreet auto-themes the greeter (wallpaper background + palette).

    # cage extends across all outputs by default, so the greeter spans both
    # monitors as one surface (login box on the bezel). cage can't mirror, so
    # pin it to a single output instead. `-m last` = only the last-connected
    # monitor; `-s` VT switching + `-d` no client-side decorations (defaults).
    services.displayManager.regreet.cageArgs = [
      "-s"
      "-d"
      "-m"
      "last"
    ];
  };
}
