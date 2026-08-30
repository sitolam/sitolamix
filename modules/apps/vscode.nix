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
      { pkgs, ... }:
      let
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
          # `anthropic.claude-code` there, and stylix drops its generated theme
          # extension in. Setting this false makes the directory a read-only
          # store symlink and silently breaks both.
          mutableExtensionsDir = true;

          profiles.default = {
            extensions = nixpkgsExtensions ++ marketplaceExtensions;

            # stylix's vscode target writes into this same option (fonts,
            # sizes, `workbench.colorTheme = "Stylix"`). It is an attrset, so
            # the two definitions merge — but only while the keys stay
            # disjoint. Never set a font or a theme key here.
            userSettings = {
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
      };

    # ensure electron apps run natively on wayland
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
