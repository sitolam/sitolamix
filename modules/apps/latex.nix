{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.apps.latex;
in
{
  options.apps.latex.enable = lib.mkEnableOption "LaTeX (TeX Live + VS Code LaTeX Workshop)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # texliveFull: matches every package a course PDF might \usepackage,
      # same trade-off the CPW guide makes on Windows/macOS (~10 GB either way).
      # (texlive.combined.scheme-full is deprecated, removed in nixpkgs 27.05.)
      pkgs.texliveFull
    ];

    home.extraOptions =
      { pkgs, ... }:
      {
        programs.vscode.profiles.default.extensions = [
          # requires apps.vscode.enable — profiles.default only exists once
          # that module sets programs.vscode.enable = true.
          pkgs.vscode-extensions.james-yu.latex-workshop
        ];

        programs.vscode.profiles.default.userSettings = {
          "latex-workshop.latex.autoBuild.run" = "onSave";
          "latex-workshop.view.pdf.viewer" = "tab";
          "latex-workshop.latex.autoClean.run" = "onBuilt";
          "latex-workshop.latex.recipe.default" = "lastUsed";
          "[latex]" = {
            "editor.wordWrap" = "on";
            "editor.formatOnSave" = false;
          };
        };
      };
  };
}
