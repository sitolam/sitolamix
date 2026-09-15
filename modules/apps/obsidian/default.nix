{ config, lib, ... }:
let
  cfg = config.apps.obsidian;
in
{
  options.apps.obsidian = {
    enable = lib.mkEnableOption "Obsidian with a declaratively deployed plugin set";

    vault = lib.mkOption {
      type = lib.types.str;
      default = "/home/otis/Documents/uni";
      description = ''
        Absolute path of the vault this module deploys plugins into.

        The vault itself is *not* part of this repo: it is its own git
        repository, committed by the obsidian-git plugin, because it is course
        notes (user data) and not system configuration. This module only owns
        the `.obsidian/` machinery inside it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, lib, ... }:
      let
        plugins = import ./_lib/plugins.nix { inherit pkgs lib; };

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

        # Plugin *code* is redeployed every activation (that is the point of
        # pinning it in Nix); each plugin's data.json — its settings — is
        # never touched, so anything configured in the app survives a rebuild.
        # A plugin dropped from ./_lib/plugins.nix would otherwise stay on disk
        # and keep running forever. Only directories carrying the marker this
        # module writes are removed, so plugins installed by hand from
        # Obsidian's own browser are never touched.
        pruneScript = ''
          for dir in "$plugdir"/*/; do
            id=$(basename "$dir")
            if [ -e "$dir/.nix-managed" ] && ! printf '%s\n' ${
              lib.concatMapStringsSep " " (p: lib.escapeShellArg p.id) plugins
            } | grep -qx "$id"; then
              rm -rf "$dir"
              if [ -e "$cfgdir/community-plugins.json" ]; then
                ${pkgs.jq}/bin/jq --arg id "$id" 'map(select(. != $id))' \
                  "$cfgdir/community-plugins.json" > "$cfgdir/community-plugins.json.tmp"
                mv "$cfgdir/community-plugins.json.tmp" "$cfgdir/community-plugins.json"
              fi
            fi
          done
        '';

        # Plugin code on disk is inert until its id is listed here, so this
        # one file cannot be seed-once like the rest: a plugin added to
        # ./_lib/plugins.nix months from now would land on disk and never
        # switch on. Union rather than overwrite, so ids Obsidian added for
        # plugins installed from its own browser survive. Consequence: a
        # plugin listed here cannot be turned off in the app, only by removing
        # it from ./_lib/plugins.nix.
        enableScript = ''
          ids=${lib.escapeShellArg (builtins.toJSON (map (p: p.id) plugins))}
          if [ -e "$cfgdir/community-plugins.json" ]; then
            ${pkgs.jq}/bin/jq -n --argjson a "$(cat "$cfgdir/community-plugins.json")" \
              --argjson b "$ids" '$a + $b | unique' > "$cfgdir/community-plugins.json.tmp"
            mv "$cfgdir/community-plugins.json.tmp" "$cfgdir/community-plugins.json"
          else
            printf '%s' "$ids" > "$cfgdir/community-plugins.json"
          fi
        '';

        deployScript = lib.concatMapStringsSep "\n" (p: ''
          install -d "$plugdir/${p.id}"
          ${lib.concatMapStringsSep "\n" (
            file: ''install -m644 "${p.files.${file}}" "$plugdir/${p.id}/${file}"''
          ) (lib.attrNames p.files)}
          touch "$plugdir/${p.id}/.nix-managed"
        '') plugins;
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

          activation.obsidianPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            cfgdir=${lib.escapeShellArg "${cfg.vault}/.obsidian"}
            plugdir=${lib.escapeShellArg "${cfg.vault}/.obsidian/plugins"}
            install -d "$plugdir"
            ${deployScript}
            ${pruneScript}
            ${seedScript}
            ${enableScript}
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
