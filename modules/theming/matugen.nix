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

    cursorTheme = lib.mkOption {
      type = lib.types.str;
      default = "Bibata-Modern-Classic";
      description = ''
        Cursor theme name. The single source for cursor identity: read by
        home.pointerCursor/dconf below and by niri's own cursor.theme setting
        (modules/desktop/niri/appearance.nix), so the two never drift.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Qt: qt5ct/qt6ct as the platform theme, so DMS's qtct colour templates
    # apply. This is NixOS's own `qt` module (nixos/modules/config/qt.nix) —
    # it only sets QT_QPA_PLATFORMTHEME and installs the packages here; it
    # must not own qt5ct.conf/qt6ct.conf, which DMS's scripts/qt.sh edits in
    # place.
    qt = {
      enable = true;
      platformTheme = "qt5ct";
    };

    home.extraOptions =
      {
        pkgs,
        # `lib` is taken explicitly so it is home-manager's — it carries
        # lib.hm.dag, used by the GTK/Qt seeding activation below — rather
        # than the NixOS lib this file closes over (see the equivalent note
        # in modules/desktop/dms/default.nix). config.fonts.* just below
        # still comes from the outer NixOS scope: config is not shadowed.
        lib,
        ...
      }:
      {
        # DMS only reads the [config] and [templates] sections of this file.
        # [config] stays empty: DMS supplies its own.
        xdg.configFile = {
          "matugen/config.toml".text = ''
            [config]

            [templates]
          ''
          + lib.concatStrings (lib.mapAttrsToList templateSection cfg.templates);

          # home-manager's gtk3.nix/gtk4.nix write these two unconditionally
          # once the gtk module is on (below), with no option to gate them
          # off. DMS rewrites gtk-3.0/settings.ini itself when the icon theme
          # is changed in its Settings UI, so a store symlink here would
          # either block that write or silently revert it on the next
          # rebuild — the same "the app writes it, not us" problem CLAUDE.md
          # lists for cliamp's config.toml. Drop these two lines if the gtk
          # module ever grows its own switch for them.
          "gtk-3.0/settings.ini".enable = lib.mkForce false;
          "gtk-4.0/settings.ini".enable = lib.mkForce false;
        };

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
          cursor-theme = cfg.cursorTheme;
          cursor-size = cfg.cursorSize;
          color-scheme = "prefer-dark";
          font-name = "${lib.head config.fonts.fontconfig.defaultFonts.sansSerif} 10";
          monospace-font-name = "${lib.head config.fonts.fontconfig.defaultFonts.monospace} 10";
        };

        # DMS's matugen run (modules/desktop/dms/theme.nix) renders
        # ~/.config/{gtk-3.0,gtk-4.0}/dank-colors.css and
        # ~/.config/{qt5ct,qt6ct}/colors/matugen.conf on every wallpaper
        # change, but only *wires* them up — the `@import
        # url("dank-colors.css")` line in gtk.css, and the
        # custom_palette/color_scheme_path keys in qt5ct.conf/qt6ct.conf —
        # from a button in DMS's own Settings UI
        # (quickshell/Common/Theme.qml's applyGtkColors()/applyQtColors(),
        # which shell out to its scripts/gtk.sh and scripts/qt.sh). Without
        # pressing that button once, GTK/Qt apps never pick up the rendered
        # colours at all.
        #
        # Running those scripts ourselves from activation was considered and
        # rejected: nixpkgs 1.6.1 go:embeds quickshell/ into the `dms`
        # binary (see the dms-shell overrideAttrs comment in
        # modules/desktop/dms/default.nix) rather than installing it under
        # $out/share, so there is no on-disk script to invoke — DMS
        # extracts it at runtime to a revision-tagged cache directory only
        # once it is running, which activation cannot rely on. So this seeds
        # the same wiring gtk.sh's fallback path and qt.sh already write,
        # by hand, once:
        #   - gtk.css: GTK always loads the user's gtk-3.0/gtk-4.0 gtk.css
        #     as an application-priority stylesheet on top of whatever theme
        #     is active, so a plain `@import` here overrides adw-gtk3-dark's
        #     colours with dank-colors.css's @define-color lines without
        #     needing gtk.sh's fancier (and file-layout-fragile) path of
        #     copying adw-gtk3 into ~/.local/share/themes and patching it in
        #     place.
        #   - qt5ct.conf/qt6ct.conf: qt5ct/qt6ct only apply a custom colour
        #     scheme when [Appearance] names one, which is exactly what
        #     qt.sh's update_qt_config writes.
        # Seeded only when missing/absent, like session.json and cache.json
        # elsewhere in this repo — never a home-manager symlink, since
        # gtk.sh explicitly refuses to touch a symlink it did not create,
        # and qt.sh/DMS rewrite these files in place afterwards. Once
        # seeded, gtk.sh's own `dms_managed_css` check (it greps for this
        # same import line) recognises the file as DMS-managed, so pressing
        # Apply in Settings later still works and can upgrade GTK3 to the
        # patched-adw-gtk3 path if it finds one.

        # home-manager's gtk module, turned on for exactly one thing: it is
        # the only thing that writes ~/.config/gtk-3.0/bookmarks (from
        # gtk.gtk3.bookmarks — modules/desktop/xdg.nix's XDG dirs and
        # modules/services/nas.nix's mounts both append to that list) and
        # the dconf keys it derives from gtk.gtk3.theme/iconTheme/etc. We
        # never set those theme options, so home-manager's own
        # dconf.settings."org/gnome/desktop/interface" write above (all
        # null -> filtered out) never fights the one above. Two more things
        # this module must keep true or gtk.enable regresses exactly what
        # the comment above this block protects:
        #   - gtk-3.0/gtk.css and gtk-4.0/gtk.css: home-manager only writes
        #     these when gtk.gtk3.extraCss/gtk.gtk4.extraCss (or gtk4's
        #     theme.package) is set. We never set them, so they stay
        #     unwritten and gtk.sh's symlink refusal above still holds.
        #   - gtk-3.0/settings.ini and gtk-4.0/settings.ini: unlike gtk.css,
        #     home-manager's gtk3.nix/gtk4.nix write these *unconditionally*
        #     once the module is on — no option gates it off. DMS rewrites
        #     gtk-3.0/settings.ini itself when the icon theme is changed in
        #     its Settings UI, so letting home-manager symlink-manage it
        #     would either block that write or get silently reverted on the
        #     next rebuild — see the two mkForce lines in xdg.configFile
        #     above. gtk2/gtk4 are turned off outright since we need nothing
        #     else from them (gtk2 writes ~/.gtkrc-2.0 unconditionally too).
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
            # newer home-manager wants this explicit rather than inferred from
            # the presence of a cursor name/package.
            enable = true;
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
