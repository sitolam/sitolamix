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
    # Qt: qt5ct/qt6ct as the platform theme, so DMS's qtct colour templates
    # apply. home-manager's `qt` module only sets the env var and installs
    # the packages here; it must not own qt5ct.conf/qt6ct.conf, which DMS's
    # scripts/qt.sh edits in place.
    qt = {
      enable = true;
      platformTheme = "qt5ct";
    };

    home.extraOptions =
      { pkgs, ... }:
      {
        # DMS only reads the [config] and [templates] sections of this file.
        # [config] stays empty: DMS supplies its own.
        xdg.configFile."matugen/config.toml".text = ''
          [config]

          [templates]
        ''
        + lib.concatStrings (lib.mapAttrsToList templateSection cfg.templates);

        home.pointerCursor = {
          name = "Bibata-Modern-Classic";
          package = pkgs.bibata-cursors;
          size = cfg.cursorSize;
          # newer home-manager wants this explicit rather than inferred from
          # the theme name (stylix used to set it).
          enable = true;
          # gtk.enable would turn on home-manager's gtk module; the cursor is
          # set through dconf below instead so nothing here owns gtk.css.
          x11.enable = true;
        };

        home.packages = [
          pkgs.adw-gtk3
          pkgs.whitesur-icon-theme
        ];

        # GTK theme, icons and cursor through gsettings rather than
        # home-manager's gtk module. That module writes gtk-3.0/gtk.css and
        # gtk-4.0/gtk.css as store symlinks, and DMS's scripts/gtk.sh refuses
        # to add its `@import url("dank-colors.css")` to a symlink it did not
        # create — which is exactly the line that carries the wallpaper
        # colours into GTK apps. adw-gtk3-dark is the base DMS copies to
        # ~/.local/share/themes and patches.
        dconf.settings."org/gnome/desktop/interface" = {
          gtk-theme = "adw-gtk3-dark";
          icon-theme = "WhiteSur-dark";
          cursor-theme = "Bibata-Modern-Classic";
          cursor-size = cfg.cursorSize;
          color-scheme = "prefer-dark";
          font-name = "${lib.head config.fonts.fontconfig.defaultFonts.sansSerif} 10";
          monospace-font-name = "${lib.head config.fonts.fontconfig.defaultFonts.monospace} 10";
        };
      };
  };
}
