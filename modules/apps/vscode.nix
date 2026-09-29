{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.apps.vscode;

  # nixd evaluates the flake itself, so it needs a concrete path
  flakeDir = "/home/otis/sitolamix";
in
{
  options.apps.vscode.enable = lib.mkEnableOption "Visual Studio Code";

  config = lib.mkIf cfg.enable {
    # adds pkgs.vscode-marketplace; extensions below prefer nixpkgs and only
    # fall back to it for what nixpkgs has never packaged
    nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

    home.extraOptions =
      { pkgs, lib, ... }:
      let
        # DMS's matugen renders into ~/.vscode/extensions/danklinux.dms-theme-*
        # but never installs the extension itself, and needs it writable —
        # home-manager's extensions would symlink a read-only store path. See
        # the activation below.
        dmsVsixBuild = "${inputs.dms}/quickshell/matugen/vsix-build";
        dmsThemeVersion = (builtins.fromJSON (builtins.readFile "${dmsVsixBuild}/package.json")).version;

        nixpkgsExtensions = with pkgs.vscode-extensions; [
          # Nix
          jnoortheen.nix-ide
          mkhl.direnv # picks up this repo's .envrc

          # Dart / Flutter
          dart-code.dart-code
          dart-code.flutter

          # Python
          ms-python.python
          ms-python.debugpy
          ms-python.vscode-pylance
          ms-toolsai.jupyter
          ms-toolsai.jupyter-keymap
          ms-toolsai.jupyter-renderers
          njpwerner.autodocstring

          myriad-dreamin.tinymist # Typst: LSP, preview and export

          # C# / .NET
          ms-dotnettools.csharp
          ms-dotnettools.vscode-dotnet-runtime

          # Git / GitHub
          eamodio.gitlens
          mhutchie.git-graph
          github.vscode-pull-request-github
          github.vscode-github-actions

          ms-vscode-remote.remote-ssh

          # Editing / diagnostics
          usernamehw.errorlens
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

          # Formats
          redhat.vscode-yaml
          mikestead.dotenv
          yzhang.markdown-all-in-one
          davidanson.vscode-markdownlint
          shd101wyy.markdown-preview-enhanced
          tomoki1207.pdf # for the Typst output loop
          humao.rest-client
        ];

        # not in nixpkgs at any version; move up once it is
        marketplaceExtensions = with pkgs.vscode-marketplace; [
          felixangelov.bloc # this codebase's state management
          jeroen-meijer.pubspec-assist
          nash.awesome-flutter-snippets
          surv.typst-math
          solidtux.zotero-for-typst
          streetsidesoftware.code-spell-checker-dutch
        ];
      in
      {
        programs.vscode = {
          enable = true;
          package = pkgs.vscode;

          # writable so Claude Code's CLI and matugen can drop files in;
          # false makes it a read-only store symlink and breaks both silently
          mutableExtensionsDir = true;

          profiles.default = {
            extensions = nixpkgsExtensions ++ marketplaceExtensions;

            # label must match dmsVsixBuild's package.json contributes.themes exactly
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

                # nix-ide ships no LSP; nixd over nil since it evaluates the
                # flake, giving option completion for services.*/home-manager.*
                "nix.enableLanguageServer" = true;
                "nix.serverPath" = lib.getExe pkgs.nixd;
                "nix.formatterPath" = lib.getExe pkgs.nixfmt;

                "nix.serverSettings".nixd = {
                  # not the flake's legacyPackages, so nixd doesn't drag in every host
                  nixpkgs.expr = ''import (builtins.getFlake "${flakeDir}").inputs.nixpkgs { }'';

                  # pinned to this host: the two hosts have different module sets
                  options = {
                    nixos.expr = ''(builtins.getFlake "${flakeDir}").nixosConfigurations.${config.networking.hostName}.options'';

                    # home-manager options live behind users.<name>'s submodule, forced open here
                    home-manager.expr = ''(builtins.getFlake "${flakeDir}").nixosConfigurations.${config.networking.hostName}.options.home-manager.users.type.getSubOptions [ ]'';
                  };

                  formatting.command = [ (lib.getExe pkgs.nixfmt) ]; # match `just fmt`
                };
              };

            keybindings = [
              # debugger detached: the only way hot reload keeps up on a large app
              {
                key = "ctrl+shift+\\";
                command = "dart.startWithoutDebugging";
              }
              # the three default bindings that squat on this chord
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

        # Re-copies everything except themes/ on every activation, so a dms
        # input bump reaches package.json; themes/ is left alone once it
        # exists so matugen's rendered colours aren't reverted to the
        # placeholder. Stale versions are removed first.
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
