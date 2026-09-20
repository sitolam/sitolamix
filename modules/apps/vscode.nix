{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.apps.vscode;

  # nixd resolves these by evaluating the flake itself, so it needs a concrete
  # path — there is no "the workspace I have open". Same hardcoded checkout as
  # modules/system/nix.nix and modules/desktop/dms/plugins.nix.
  flakeDir = "/home/otis/sitolamix";
in
{
  options.apps.vscode.enable = lib.mkEnableOption "Visual Studio Code";

  config = lib.mkIf cfg.enable {
    # nix-vscode-extensions' overlay adds `pkgs.vscode-marketplace` (and
    # `pkgs.open-vsx`). Extensions below come from nixpkgs wherever nixpkgs has
    # them — those are cached and move with the rest of the tree — and from the
    # marketplace mirror only for the few nixpkgs has never packaged.
    nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

    home.extraOptions =
      { pkgs, lib, ... }:
      let
        # DMS's VS Code theme extension. DMS never installs this itself — its
        # matugen integration (core/internal/matugen/matugen.go) only globs
        # ~/.vscode/extensions/danklinux.dms-theme-* and, on a match, renders
        # themes/*.json into it; with no match it returns silently and VS Code
        # keeps whatever colorTheme is set with no error. So this repo has to
        # install the extension shell itself, from DMS's own VSIX build tree,
        # as a *writable* copy — home-manager's `programs.vscode…extensions`
        # would symlink a read-only store path, which matugen cannot write
        # into. See the activation below.
        dmsVsixBuild = "${inputs.dms}/quickshell/matugen/vsix-build";
        dmsThemeVersion = (builtins.fromJSON (builtins.readFile "${dmsVsixBuild}/package.json")).version;

        nixpkgsExtensions = with pkgs.vscode-extensions; [
          # ── Nix ────────────────────────────────────────────────────────
          jnoortheen.nix-ide # LSP client; nil/nixd, syntax, formatting
          mkhl.direnv # picks up this repo's .envrc so the editor sees the devshell

          # ── Dart / Flutter ─────────────────────────────────────────────
          dart-code.dart-code
          dart-code.flutter

          # ── Python ─────────────────────────────────────────────────────
          ms-python.python
          ms-python.debugpy
          ms-python.vscode-pylance
          ms-toolsai.jupyter
          ms-toolsai.jupyter-keymap
          ms-toolsai.jupyter-renderers
          njpwerner.autodocstring

          # ── Typst ──────────────────────────────────────────────────────
          myriad-dreamin.tinymist # LSP, preview and export; the whole toolchain

          # ── C# / .NET ──────────────────────────────────────────────────
          ms-dotnettools.csharp
          ms-dotnettools.vscode-dotnet-runtime

          # ── Git / GitHub ───────────────────────────────────────────────
          eamodio.gitlens
          mhutchie.git-graph
          github.vscode-pull-request-github
          github.vscode-github-actions

          # ── Remote ─────────────────────────────────────────────────────
          ms-vscode-remote.remote-ssh

          # ── Editing / diagnostics ──────────────────────────────────────
          usernamehw.errorlens # inlines diagnostics at end of line
          editorconfig.editorconfig
          esbenp.prettier-vscode
          streetsidesoftware.code-spell-checker
          gruntfuggly.todo-tree
          aaron-bond.better-comments
          oderwat.indent-rainbow
          shardulm94.trailing-spaces
          wmaurer.change-case
          formulahendry.auto-rename-tag
          vincaslt.highlight-matching-tag

          # ── Formats ────────────────────────────────────────────────────
          redhat.vscode-yaml
          mikestead.dotenv
          yzhang.markdown-all-in-one
          davidanson.vscode-markdownlint
          shd101wyy.markdown-preview-enhanced
          tomoki1207.pdf # opens PDFs in a tab — the Typst output loop
          humao.rest-client
        ];

        # Not in nixpkgs at any version, hence the marketplace mirror. These are
        # fetched from Microsoft's CDN at build time and are in no binary cache;
        # drop the entry and move it up to `nixpkgsExtensions` if nixpkgs ever
        # packages one.
        marketplaceExtensions = with pkgs.vscode-marketplace; [
          felixangelov.bloc # BLoC scaffolding; the state management this codebase uses
          jeroen-meijer.pubspec-assist # add a pub dependency without hand-editing pubspec.yaml
          nash.awesome-flutter-snippets
          surv.typst-math # unicode preview of Typst math
          solidtux.zotero-for-typst # cite from the Zotero library into Typst
          streetsidesoftware.code-spell-checker-dutch # NL dictionary for the spell checker above
        ];
      in
      {
        programs.vscode = {
          enable = true;
          package = pkgs.vscode;

          # Nix symlinks its own extensions in but leaves ~/.vscode/extensions
          # writable, so anything installed out-of-band survives. Two things
          # rely on that: Claude Code's CLI installs and self-updates
          # `anthropic.claude-code` there, and matugen writes the
          # wallpaper-rendered theme JSON into the danklinux.dms-theme-*
          # extension the activation below deploys. Setting this false makes
          # the directory a read-only store symlink and silently breaks both.
          mutableExtensionsDir = true;

          profiles.default = {
            extensions = nixpkgsExtensions ++ marketplaceExtensions;

            # Theme and fonts live here now. The theme extension itself is
            # deployed by the activation below; matugen renders its colours
            # into it at runtime. The label has to match one of
            # dmsVsixBuild's package.json `contributes.themes` exactly.
            userSettings =
              let
                monoFont = lib.head config.fonts.fontconfig.defaultFonts.monospace;
                sansFont = lib.head config.fonts.fontconfig.defaultFonts.sansSerif;
              in
              {
                "workbench.colorTheme" = "Dynamic Base16 DankShell (Dark)";
                "editor.fontFamily" = monoFont;
                "editor.fontSize" = 20;
                "terminal.integrated.fontSize" = 20;
                "debug.console.fontFamily" = monoFont;
                "debug.console.fontSize" = 20;
                "scm.inputFontFamily" = monoFont;
                "chat.editor.fontFamily" = monoFont;
                "chat.editor.fontSize" = 20;
                "chat.fontFamily" = sansFont;
                "markdown.preview.fontFamily" = sansFont;
                "markdown.preview.fontSize" = 20;
                "notebook.markup.fontFamily" = sansFont;

                # nix-ide ships no language server; without these three keys it
                # is a syntax highlighter. nixd over nil because it evaluates the
                # flake, which is what buys option completion and hover docs for
                # `services.*`/`home-manager.*` — the bulk of what gets typed in
                # this repo. Absolute store paths so neither binary has to be on
                # PATH.
                "nix.enableLanguageServer" = true;
                "nix.serverPath" = lib.getExe pkgs.nixd;
                "nix.formatterPath" = lib.getExe pkgs.nixfmt;

                "nix.serverSettings".nixd = {
                  # Package completion. `import ... { }` and not the flake's own
                  # legacyPackages so nixd does not drag in every host.
                  nixpkgs.expr = ''import (builtins.getFlake "${flakeDir}").inputs.nixpkgs { }'';

                  # Option completion. Pinned to *this* host: the two hosts have
                  # different module sets, and nixd takes one expression.
                  options = {
                    nixos.expr = ''(builtins.getFlake "${flakeDir}").nixosConfigurations.${config.networking.hostName}.options'';

                    # home-manager options live behind `users.<name>`, whose
                    # submodule has to be forced open before nixd can see inside.
                    home-manager.expr = ''(builtins.getFlake "${flakeDir}").nixosConfigurations.${config.networking.hostName}.options.home-manager.users.type.getSubOptions [ ]'';
                  };

                  # Match `just fmt`, so the editor and treefmt never fight.
                  formatting.command = [ (lib.getExe pkgs.nixfmt) ];
                };
              };

            keybindings = [
              # F5-adjacent: run a Flutter app with the debugger detached, which
              # is the only way hot reload keeps up on a large app.
              {
                key = "ctrl+shift+\\";
                command = "dart.startWithoutDebugging";
              }
              # ...and the three default bindings that squat on that chord.
              {
                key = "ctrl+shift+\\";
                command = "-editor.action.jumpToBracket";
                when = "editorTextFocus";
              }
              {
                key = "ctrl+shift+\\";
                command = "-workbench.action.terminal.focusTabs";
                when = "terminalFocus && terminalHasBeenCreated || terminalFocus && terminalProcessSupported || terminalHasBeenCreated && terminalTabsFocus || terminalProcessSupported && terminalTabsFocus";
              }
              {
                key = "ctrl+alt+\\";
                command = "-jupyter.selectCellContents";
                when = "editorTextFocus && jupyter.hascodecells && !jupyter.webExtension && !notebookEditorFocused";
              }
            ];
          };
        };

        # Deploys DMS's VSIX build tree as a writable copy, because matugen
        # writes themes/*.json into the extension directory it finds by glob
        # (danklinux.dms-theme-*) and a home-manager-managed extension would
        # be a read-only store symlink. Re-copies everything except themes/
        # on every activation, so a `dms` input bump reaches package.json,
        # README etc.; themes/ is left alone once it exists because matugen
        # has usually already rendered real wallpaper colours into it by the
        # time this runs, and clobbering it would revert VS Code to
        # vsix-build's static placeholder until the next wallpaper change or
        # DMS restart. Stale copies from an earlier dms input version are
        # removed so the glob above always has exactly one match.
        home.activation.deployDmsVscodeTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          extBase="$HOME/.vscode/extensions"
          extDir="$extBase/danklinux.dms-theme-${dmsThemeVersion}"
          run mkdir -p "$extBase"

          for old in "$extBase"/danklinux.dms-theme-*; do
            [ -e "$old" ] || continue
            [ "$old" = "$extDir" ] && continue
            run rm -rf "$old"
          done

          if [ ! -d "$extDir" ]; then
            run mkdir -p "$extDir"
            run cp -rT --no-preserve=mode ${dmsVsixBuild} "$extDir"
            run chmod -R u+w "$extDir"
          else
            run ${pkgs.rsync}/bin/rsync -a --chmod=D755,F644 --exclude=themes/ ${dmsVsixBuild}/ "$extDir/"
            run chmod -R u+w "$extDir"
          fi
        '';
      };

    # ensure electron apps run natively on wayland
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
