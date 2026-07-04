_:
{
  flake.modules.nixos.school =
    { pkgs, ... }:
    {
      home.extraOptions = {
        home.packages = with pkgs; [
          anki
          antimicrox
          zotero
          onlyoffice-desktopeditors
          typst
        ];
      };
    };
}
