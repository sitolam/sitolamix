# Theme registry — quickhyprnix-style. Each ./<name>.nix returns a theme attrset
# (themeName / polarity / wallpaper / override / dms). Consumed by
# modules/desktop/stylix.nix and modules/desktop/dms.nix, selected via the
# `theming.stylix.theme` option. Lives outside ./modules so import-tree doesn't
# try to load these data files as NixOS modules.
{ lib }:
let
  themes = {
    catppuccin-mocha = import ./catppuccin-mocha.nix { };
  };
in
{
  inherit themes;

  get =
    name:
    themes.${name}
      or (throw "Unknown theme: ${name}. Available: ${lib.concatStringsSep ", " (lib.attrNames themes)}");
}
