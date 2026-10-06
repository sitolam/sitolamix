{ config, lib, ... }:
let
  cfg = config.suites.school;
in
{
  options.suites.school.enable = lib.mkEnableOption "study / office apps";

  config = lib.mkIf cfg.enable {
    # Anki is a module of its own (modules/apps/anki) — it carries an addon
    # tree, two sops secrets and a theme-driven activation script, which is far
    # more than a suite should hold.
    apps = {
      anki.enable = true;

      # Obsidian likewise carries its own module: it themes the notes vault
      # from the wallpaper; plugins live in the vault's own git repository.
      obsidian.enable = true;

      oop-apps.enable = true;

      # requires apps.vscode.enable (suites.development) for the
      # LaTeX Workshop extension to have a profile to attach to.
      latex.enable = true;

      xournalpp.enable = true;
    };

    # Pen tablet for handwritten notes in apps.xournalpp.
    hardware.drawing-tablet.enable = true;

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          antimicrox
          # nixpkgs' zotero fails to build since a Firefox bump. Stable only has
          # Zotero 9, which can't open a 10.x library, so pin the last nixpkgs
          # that built 10.0.2. Drop once NixOS/nixpkgs#569006 lands.
          (import (fetchTarball {
            url = "https://github.com/NixOS/nixpkgs/archive/8d5d270900d3fc75655ea2d9d248b234f6631439.tar.gz";
            sha256 = "sha256-fXrm/q9klVBtVq5rGQ+XpI/dokPuSB15ZK2CZvWxXOk=";
          }) { inherit (pkgs.stdenv.hostPlatform) system; }).zotero
          onlyoffice-desktopeditors
          # GUI front-end for libqalculate — the same engine the DMS launcher's
          # calculator plugin shells out to (modules/desktop/dms/plugins.nix),
          # for the sums that outgrow a one-line launcher field.
          qalculate-gtk
          typst
          tinymist # Typst language server (LSP for editors)
        ];
      };
  };
}
