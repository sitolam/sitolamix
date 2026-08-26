# Theme registry — quickhyprnix-style. Each ./<name>.nix returns a theme attrset
# (themeName / polarity / wallpaper / override / dms). Consumed by
# modules/theming/stylix.nix, modules/desktop/dms/theme.nix and
# modules/apps/anki, selected via the `theming.stylix.theme` option. Lives at
# the repo root rather than under ./modules because it is cross-cutting data
# read by several modules -- app-specific data lives beside its module in a
# `_lib` directory instead (see modules/apps/anki/_lib).
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
