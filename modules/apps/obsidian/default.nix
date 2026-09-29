{ config, lib, ... }:
let
  cfg = config.apps.obsidian;
in
{
  options.apps.obsidian = {
    enable = lib.mkEnableOption "Obsidian with wallpaper-driven theming";

    vault = lib.mkOption {
      type = lib.types.str;
      # only one vault is managed at a time; an older vault keeps its last snippet
      default = "/home/otis/Documents/Obsidian notes/School";
      description = ''
        Absolute path of the vault this module themes. The vault itself is
        its own git repository (user data, not this repo); this module only
        seeds first-run settings and writes the matugen CSS snippet.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, lib, ... }:
      let
        # written once, then left to Obsidian: it rewrites .obsidian/ files
        # the moment a setting is toggled, so re-seeding would undo them
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
            livePreview = true; # maths renders while LaTeX source stays editable
            newFileLocation = "current"; # unresolved [[link]] notes land next to their source
            attachmentFolderPath = "04 Excalidraw";
            alwaysUpdateLinks = true;
            useMarkdownLinks = false;
            showLineNumber = false;
            showInlineTitle = false; # every note already has its own `# Titel` heading
            spellcheck = false; # no Dutch dictionary on Linux without extra hunspell wiring
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

        # merged, not written whole: appearance.json also holds zoom, font
        # sizes and the user's own snippet list. accentColor is dropped so a
        # static hex doesn't override the snippet's wallpaper-driven colours.
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

          # Obsidian's self-updater downloads a newer app.asar and runs that
          # instead of the store build; merge updateDisabled=true into
          # obsidian.json rather than rewrite it, since it also holds the vault registry.
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
      output = "${cfg.vault}/.obsidian/snippets/sitolamix.css";
    };
  };
}
