{ config, lib, ... }:
let
  cfg = config.apps.xournalpp;

  # Merged into settings.xml on every launch; anything not listed here is
  # left as Xournal++ wrote it.
  settings = {
    pressureSensitivity = "true";
    minimumPressure = "0.05";
    # a little thicker at the same pen pressure; the next pen size up is too much
    pressureMultiplier = "1.3";
  };
in
{
  options.apps.xournalpp.enable = lib.mkEnableOption "Xournal++ handwritten notes";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      let
        # Applied by a launch wrapper, not by activation: Xournal++ rewrites
        # settings.xml on exit, which would undo it. Both binaries are
        # wrapped; the desktop entry uses the second.
        apply = pkgs.writeShellScript "xournalpp-apply-settings" ''
          ${pkgs.python3}/bin/python3 ${./apply-settings.py} \
            ${pkgs.writeText "xournalpp-settings.json" (builtins.toJSON settings)} || true
        '';

        # Two behaviours Xournal++ hardcodes in its canvas, so no setting or
        # plugin can reach them; the price is building Xournal++ locally.
        #  - Left/Right flip pages instead of scrolling sideways.
        #  - Ctrl held when the pen touches down draws a straight line,
        #    snapped to angles but not to the grid.
        xournalpp = pkgs.xournalpp.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ./arrow-keys-flip-pages.patch
            ./ctrl-straight-line.patch
          ];
        });

        xournalpp-wrapped = pkgs.symlinkJoin {
          name = "xournalpp-wrapped";
          paths = [ xournalpp ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            for bin in xournalpp xournalpp-wrapper; do
              rm $out/bin/$bin
              makeWrapper ${xournalpp}/bin/$bin $out/bin/$bin --run ${apply}
            done
          '';
        };
      in
      {
        home.packages = [ xournalpp-wrapped ];

        # Pen/highlighter toggle and colour cycling for the tablet's keys
        # (hardware.drawing-tablet sends Alt+M and Alt+C).
        xdg.configFile."xournalpp/plugins/TabletKeys".source = ./tablet-keys;
      };
  };
}
