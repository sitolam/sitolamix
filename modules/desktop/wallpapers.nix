{
  config,
  lib,
  inputs,
  ...
}:
let
  # orangci/walls-catppuccin-mocha — a flake input, so the images live in the
  # Nix store and nowhere else. 335 files, ~396 MB. (GitHub reports 795 MB for
  # the repo; that counts git history the tarball does not carry.)
  collection = inputs.wallpapers;

  # The wallpaper DMS starts on. Pointing it *into the collection* is what makes
  # the directory declarative: DMS has no wallpaper-folder setting, but
  # Services/WallpaperCyclingService.qml derives the folder it cycles through
  # from the current wallpaper's own directory —
  #
  #   const wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'))
  #
  # — so seeding a path inside the store collection sets the folder for free,
  # and cycling covers all 335 images.
  default = "cat-in-clouds.png";

  # Guard the filename against an input update renaming it: fall back to the
  # first image rather than silently seeding a path that does not exist. Plain
  # readDir on a store path, so no import-from-derivation.
  images = lib.naturalSort (
    lib.attrNames (
      lib.filterAttrs (
        name: type:
        type == "regular"
        && lib.any (ext: lib.hasSuffix ext (lib.toLower name)) [
          ".jpg"
          ".png"
        ]
      ) (builtins.readDir collection)
    )
  );
  chosen = if lib.elem default images then default else lib.head images;
in
{
  config = lib.mkIf config.desktop.dms.enable {
    # `home.file` with a directory source symlinks the store path — it does not
    # copy. ~/Pictures/Wallpapers is a pointer costing no disk; it exists only so
    # DMS's file browser has a stable, navigable path (the store path changes
    # with every input update, and DMS keeps its last-browsed directory in its
    # cache rather than its settings, so it cannot be preselected).
    home.extraOptions.home.file."Pictures/Wallpapers".source = collection;

    # Consumed by the session.json seeding in ./dms/default.nix.
    desktop.dms.initialWallpaper = "${collection}/${chosen}";
  };
}
