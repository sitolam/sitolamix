{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.apps.keydrill;
in
{
  options.apps.keydrill.enable = lib.mkEnableOption "keydrill keyboard-shortcut trainer";

  config = lib.mkIf cfg.enable {
    # Own tool (github:sitolam/keydrill): nixpkgs has nothing for keyboard
    # shortcut training, the alternatives (KeyCombiner, ShortcutFoo) are
    # closed and hosted.
    nixpkgs.overlays = [ inputs.keydrill.overlays.default ];

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.keydrill ];

        # practiceCommand releases niri's key grabs so keydrill can read them,
        # restoring them on exit. Must run in ghostty, not the ambient
        # terminal: keydrill needs the Kitty keyboard protocol to report
        # Super, which an ordinary terminal can't. Args must stay separate —
        # `ghostty -e` execs them as argv, and one spaced string is a program
        # name that doesn't exist.
        programs.niri.settings.binds."Mod+Alt+P".action.spawn = [
          config.desktop.niri.practiceCommand
          "run"
          "ghostty"
          "-e"
          (lib.getExe pkgs.keydrill)
          "run"
          "--from"
          "niri"
        ];
      };
  };
}
