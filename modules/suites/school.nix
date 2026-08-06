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
          # unstable's anki 25.09.4 fails to build: its offline uv resolve dies
          # with "iniconfig was not found in the cache" (nixpkgs packaging bug,
          # not ours). The stable set has the same 25.09.4 and builds -- it
          # substitutes straight from cache.nixos.org. See
          # modules/system/nixpkgs-stable.nix; drop the `stable.` once unstable
          # is fixed.
          stable.anki
          antimicrox
          zotero
          onlyoffice-desktopeditors
          typst
          tinymist # Typst language server (LSP for editors)
        ];
      };
  };
}
