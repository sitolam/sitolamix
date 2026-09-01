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
    apps.anki.enable = true;

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          antimicrox
          zotero
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
