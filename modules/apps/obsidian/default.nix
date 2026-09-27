{ config, lib, ... }:
let
  cfg = config.apps.obsidian;
in
{
  options.apps.obsidian = {
    enable = lib.mkEnableOption "Obsidian with wallpaper-driven theming";

    vault = lib.mkOption {
      type = lib.types.str;
      # Documents/uni was the first vault; this one replaced it in 2026-09.
      # Only one vault is managed at a time — the generated CSS snippet lands
      # here, and an older vault keeps whatever snippet it last received.
      default = "/home/otis/Documents/Obsidian notes/School";
      description = ''
        Absolute path of the vault this module themes.

        The vault itself is *not* part of this repo: it is its own git
        repository, committed by the obsidian-git plugin, because it is course
        notes (user data) and not system configuration. Community plugins are
        installed from Obsidian's own browser and live in that repository
        under `.obsidian/plugins/`; this module only seeds first-run settings
        and writes the matugen CSS snippet.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, lib, ... }:
      let
        # Written once, then left to Obsidian. Every file under .obsidian/ is
        # rewritten by the app the moment a setting is toggled, so seeding is
        # the only honest option: a file this module rewrote on every
        # activation would silently undo changes made in the app's own
        # settings UI. Change a *plugin version* here; change a *setting* in
        # Obsidian.
        seeds = {
          "core-plugins.json" = builtins.toJSON {
            "file-explorer" = true;
            "global-search" = true;
            "switcher" = true;
            "graph" = true;
            "backlink" = true;
            "outgoing-link" = true;
            "tag-pane" = true;
            "outline" = true;
            "templates" = true;
            "daily-notes" = true;
            "command-palette" = true;
            "editor-status" = true;
            "bookmarks" = true;
            "properties" = true;
          };

          "app.json" = builtins.toJSON {
            # Lectures are typed, not clicked: live preview renders the maths
            # while the LaTeX source stays editable under the cursor.
            livePreview = true;
            # New note from an unresolved [[link]] lands next to its source
            # instead of in the vault root.
            newFileLocation = "current";
            attachmentFolderPath = "04 Excalidraw";
            alwaysUpdateLinks = true;
            useMarkdownLinks = false;
            showLineNumber = false;
            # Every note already opens with its own `# Titel` heading, and
            # Obsidian renders the filename above that — two identical titles
            # on every page without this.
            showInlineTitle = false;
            # Obsidian's own spellchecker has no Dutch dictionary on Linux
            # without extra system hunspell wiring; red squiggles under every
            # Dutch word are worse than none.
            spellcheck = false;
          };

          "templates.json" = builtins.toJSON {
            folder = "99 Meta/Templates";
            dateFormat = "YYYY-MM-DD";
          };

          "daily-notes.json" = builtins.toJSON {
            folder = "00 Dagelijks";
            format = "YYYY-MM-DD";
            template = "99 Meta/Templates/Dag.md";
          };
        };

        seedScript = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: json: ''
            if [ ! -e "$cfgdir/${name}" ]; then
              printf '%s' ${lib.escapeShellArg json} > "$cfgdir/${name}"
            fi
          '') seeds
        );

        # The snippet is inert until Obsidian is told to load it. The base
        # theme is always "obsidian" (dark) because the matugen scheme is
        # always dark; accentColor is removed because a static hex here
        # would override the snippet's wallpaper-driven --accent-h/s/l.
        # Merged rather than written whole: appearance.json also holds zoom,
        # font sizes and the user's own snippet list.
        appearanceScript = ''
          appearance="$cfgdir/appearance.json"
          [ -e "$appearance" ] || printf '%s' '{}' > "$appearance"
          ${pkgs.jq}/bin/jq \
            '.theme = "obsidian"
             | del(.accentColor)
             | .enabledCssSnippets = ((.enabledCssSnippets // []) + ["sitolamix"] | unique)' \
            "$appearance" > "$appearance.tmp"
          mv "$appearance.tmp" "$appearance"
        '';

      in
      {
        home = {
          packages = [ pkgs.obsidian ];

          # Obsidian ships its own updater: it downloads a newer app.asar into
          # ~/.config/obsidian and runs that instead of the one in the Nix
          # store, so `pkgs.obsidian` stops describing what actually runs (seen
          # here as "Version 1.13.7 / Installer version 1.13.4"). The app's own
          # setting for this writes `updateDisabled` into obsidian.json, so set
          # that key -- merged, never rewritten, because the same file holds the
          # vault registry.
          activation.obsidianNoSelfUpdate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            conf="$HOME/.config/obsidian/obsidian.json"
            install -d "$HOME/.config/obsidian"
            if [ -e "$conf" ]; then
              ${pkgs.jq}/bin/jq '.updateDisabled = true' "$conf" > "$conf.tmp"
              mv "$conf.tmp" "$conf"
            else
              printf '%s' '{"updateDisabled":true}' > "$conf"
            fi
          '';

          activation.obsidianVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            cfgdir=${lib.escapeShellArg "${cfg.vault}/.obsidian"}
            install -d "$cfgdir"
            ${seedScript}
            install -d "$cfgdir/snippets"
            ${appearanceScript}
          '';
        };
      };

    theming.matugen.templates.obsidian = {
      input = builtins.toFile "obsidian-sitolamix.css" (
        import ./_lib/matugen-css.nix {
          inherit lib;
          fonts = {
            serif = lib.head config.fonts.fontconfig.defaultFonts.serif;
            sansSerif = lib.head config.fonts.fontconfig.defaultFonts.sansSerif;
            monospace = lib.head config.fonts.fontconfig.defaultFonts.monospace;
          };
        }
      );
      # Written straight into the vault. The snippet is derived entirely from
      # the wallpaper, so rebuilds no longer touch it.
      output = "${cfg.vault}/.obsidian/snippets/sitolamix.css";
    };
  };
}
