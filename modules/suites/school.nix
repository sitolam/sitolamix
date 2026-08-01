{ config, lib, ... }:
let
  cfg = config.suites.school;
in
{
  options.suites.school.enable = lib.mkEnableOption "study / office apps";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          anki
          antimicrox
          zotero
          onlyoffice-desktopeditors
          typst
          tinymist # Typst language server (LSP for editors)
        ];
      };
  };
}
