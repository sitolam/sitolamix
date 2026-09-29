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
        Matugen user templates. Each application module declares its own;
        this module collects them into ~/.config/matugen/config.toml,
        appended to DMS's own matugen run. Templates re-render on wallpaper
        change, not on rebuild.
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
        cursor.xcursor-size). HiDPI hosts override it.
      '';
    };

    cursorTheme = lib.mkOption {
      type = lib.types.str;
      default = "Bibata-Modern-Classic";
      description = ''
        Cursor theme name, read by home.pointerCursor/dconf below and by
        niri's own cursor.theme setting, so the two never drift.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # NixOS's own `qt` module only sets QT_QPA_PLATFORMTHEME and installs
    # packages; must not own qt5ct.conf/qt6ct.conf — DMS's scripts/qt.sh
    # edits those in place.
    qt = {
      enable = true;
      platformTheme = "qt5ct";
    };

    home.extraOptions =
      {
        pkgs,
        # `lib` here is home-manager's (carries lib.hm.dag); config.fonts.*
        # below still comes from the outer NixOS scope.
        lib,
        ...
      }:
      {
        # DMS only reads [config]/[templates] here; [config] stays empty —
        # DMS supplies its own.
        xdg.configFile = {
          "matugen/config.toml".text = ''
            [config]

            [templates]
          ''
          + lib.concatStrings (lib.mapAttrsToList templateSection cfg.templates);

          # home-manager's gtk module writes these unconditionally with no
          # way to gate them off, but DMS rewrites gtk-3.0/settings.ini
          # itself. Drop if the gtk module grows its own switch for them.
          "gtk-3.0/settings.ini".enable = lib.mkForce false;
          "gtk-4.0/settings.ini".enable = lib.mkForce false;
        };

        # GTK theme/icons/cursor via gsettings, not home-manager's gtk
        # module: that module writes gtk.css as a store symlink, and DMS's
        # scripts/gtk.sh refuses to add its @import to a symlink it didn't
        # create. adw-gtk3-dark is the base DMS copies and patches.
        dconf.settings."org/gnome/desktop/interface" = {
          gtk-theme = "adw-gtk3-dark";
          icon-theme = "WhiteSur-dark";
          cursor-theme = cfg.cursorTheme;
          cursor-size = cfg.cursorSize;
          color-scheme = "prefer-dark";
          font-name = "${lib.head config.fonts.fontconfig.defaultFonts.sansSerif} 10";
          monospace-font-name = "${lib.head config.fonts.fontconfig.defaultFonts.monospace} 10";
        };

        # DMS wires dank-colors.css / qt5ct+qt6ct into GTK/Qt only from a
        # button in its own Settings UI — unreachable from activation since
        # that script is embedded in the `dms` binary, not on disk. Seed the
        # same wiring here once, only when missing; never a symlink, which
        # gtk.sh refuses to touch. gtk.sh still recognises the seed as its own.

        # gtk module only for ~/.config/gtk-3.0/bookmarks (appended
        # elsewhere). We never set theme/iconTheme/extraCss, so it can't
        # fight the dconf write above. gtk2/gtk4 stay off — gtk2 writes
        # ~/.gtkrc-2.0 unconditionally.
        gtk = {
          enable = true;
          gtk2.enable = false;
          gtk4.enable = false;
        };

        home = {
          pointerCursor = {
            name = cfg.cursorTheme;
            package = pkgs.bibata-cursors;
            size = cfg.cursorSize;
            enable = true; # newer home-manager wants this explicit
            x11.enable = true;
          };

          packages = [
            pkgs.adw-gtk3
            pkgs.whitesur-icon-theme
          ];

          # Drop this activation block if DMS ever wires GTK/Qt as part of
          # its matugen run itself, rather than only from its Settings UI.
          activation.seedGtkQtColorWiring = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            for css in "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"; do
              run mkdir -p "$(dirname "$css")"
              if [ ! -e "$css" ]; then
                run sh -c 'printf "%s\n" "$1" > "$2"' -- '@import url("dank-colors.css");' "$css"
              elif [ ! -L "$css" ] && ! grep -q '^@import url(.*dank-colors\.css.*);$' "$css"; then
                run sed -i '1i\@import url("dank-colors.css");' "$css"
              fi
            done

            for name in qt5ct qt6ct; do
              conf="$HOME/.config/$name/$name.conf"
              if [ ! -e "$conf" ]; then
                run mkdir -p "$(dirname "$conf")"
                run sh -c 'printf "[Appearance]\ncustom_palette=true\ncolor_scheme_path=%s/.local/share/color-schemes/DankMatugen.colors\n" "$1" > "$2"' -- "$HOME" "$conf"
              fi
            done
          '';
        };
      };
  };
}
