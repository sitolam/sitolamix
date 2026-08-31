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
    # Our own tool (github:sitolam/keydrill). Nothing in nixpkgs trains
    # keyboard shortcuts: the field is KeyCombiner and ShortcutFoo, both
    # closed and hosted.
    nixpkgs.overlays = [ inputs.keydrill.overlays.default ];

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.keydrill ];

        # keydrill needs the keys it is drilling, so niri has to stop
        # grabbing them first — practice mode does that, and restores them
        # however keydrill exits. Mod+Alt+<letter> is the "run a tool" plane,
        # see ../desktop/niri/KEYBINDINGS.md.
        #
        # ghostty rather than the ambient terminal because keydrill requires
        # the Kitty keyboard protocol: an ordinary terminal cannot report
        # Super at all, which would make most of the deck unanswerable.
        # Every argument separate: `ghostty -e` execs what follows as argv,
        # so a single string with spaces in it is one program name that does
        # not exist, and the window closes the instant it opens.
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
