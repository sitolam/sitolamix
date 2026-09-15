{ config, lib, ... }:
let
  cfg = config.theming.matugen;

  # TOML basic strings: escape backslash and double quote.
  str = s: ''"${lib.escape [ "\\" "\"" ] s}"'';

  templateSection =
    name: t:
    ''
      [templates.${name}]
      input_path = ${str "${t.input}"}
      output_path = ${str t.output}
    ''
    + lib.optionalString (t.postHook != null) ''
      post_hook = ${str t.postHook}
    '';
in
{
  options.theming.matugen = {
    enable = lib.mkEnableOption "wallpaper-driven colours through DankMaterialShell's matugen run";

    templates = lib.mkOption {
      default = { };
      description = ''
        Matugen user templates. Each application module declares its own
        template next to itself; this module only collects them into
        ~/.config/matugen/config.toml, whose [templates] section DMS appends
        to its own matugen run (runUserMatugenTemplates, see
        modules/desktop/dms/theme.nix). So every template re-renders whenever
        the wallpaper changes, not on rebuild.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            input = lib.mkOption {
              type = lib.types.path;
              description = "Template file, using {{colors.*}} / {{dank16.*}} tokens.";
            };
            output = lib.mkOption {
              type = lib.types.str;
              description = "Absolute path matugen writes the rendered file to.";
            };
            postHook = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Shell command matugen runs after writing this template.";
            };
          };
        }
      );
    };

    cursorSize = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = ''
        Cursor size, logical/unscaled (same unit as niri's
        cursor.xcursor-size), so it does not grow with output scale. HiDPI
        hosts override it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # DMS only reads the [config] and [templates] sections of this file.
    # [config] stays empty: DMS supplies its own.
    home.extraOptions.xdg.configFile."matugen/config.toml".text = ''
      [config]

      [templates]
    ''
    + lib.concatStrings (lib.mapAttrsToList templateSection cfg.templates);
  };
}
