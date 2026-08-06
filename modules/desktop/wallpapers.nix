{
  config,
  lib,
  inputs,
  ...
}:
{
  # orangci/walls-catppuccin-mocha (flake input, 335 images / ~396 MB) linked
  # into the home directory so DMS's wallpaper browser can reach them.
  #
  # A symlink to the store path rather than a copy: the collection is read-only
  # and DMS only ever reads from here — the wallpaper you pick is recorded in
  # ~/.local/state/DankMaterialShell/session.json, which is DMS's own file (see
  # ./dms/default.nix). Nothing here makes stylix follow the wallpaper; colours
  # stay on the theme's base16 scheme.
  #
  # DMS remembers the last browsed directory in its cache, not in settings, so
  # there is no declarative way to point the browser here — browse to
  # ~/Pictures/Wallpapers once and it will reopen there.
  config = lib.mkIf config.desktop.dms.enable {
    home.extraOptions.home.file."Pictures/Wallpapers".source = inputs.wallpapers;
  };
}
