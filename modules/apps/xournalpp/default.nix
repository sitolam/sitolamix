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

  colorsFile = "${config.users.users.otis.home}/.local/state/sitolamix/xournalpp-colors.json";
in
{
  options.apps.xournalpp.enable = lib.mkEnableOption "Xournal++ handwritten notes";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      let
        # Applied by a launch wrapper, not by activation or a matugen post
        # hook: Xournal++ rewrites settings.xml on exit, which would undo
        # either. Both binaries are wrapped; the desktop entry uses the second.
        apply = pkgs.writeShellScript "xournalpp-apply-settings" ''
          ${pkgs.python3}/bin/python3 ${./apply-settings.py} \
            ${pkgs.writeText "xournalpp-settings.json" (builtins.toJSON settings)} \
            ${lib.escapeShellArg colorsFile} || true
        '';

        xournalpp-wrapped = pkgs.symlinkJoin {
          name = "xournalpp-wrapped";
          paths = [ pkgs.xournalpp ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            for bin in xournalpp xournalpp-wrapper; do
              rm $out/bin/$bin
              makeWrapper ${pkgs.xournalpp}/bin/$bin $out/bin/$bin --run ${apply}
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

    # The window chrome already follows DMS's GTK colours; this covers the
    # colours Xournal++ keeps in its own settings.
    theming.matugen.templates.xournalpp = {
      input = ./colors.json;
      output = colorsFile;
    };
  };
}
