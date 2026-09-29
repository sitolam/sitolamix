{
  config,
  lib,
  inputs,
  ...
}:
let
  # sitolam/mywalls — own collection, kept flat (no category folders) so DMS's
  # WallpaperCyclingService, which cycles the current wallpaper's own
  # directory, covers the whole set rather than one subfolder.
  collection = inputs.wallpapers;

  # First image by natural sort: the wallpaper DMS starts on. Plain readDir
  # on the store path, so nothing to break when the input gains or loses
  # files. Static .gif/.mp4 are left out — only DMS's still-image pipeline
  # seeds cleanly; pick those in the UI.
  images = lib.naturalSort (
    lib.attrNames (
      lib.filterAttrs (
        name: type:
        type == "regular"
        && lib.any (ext: lib.hasSuffix ext (lib.toLower name)) [
          ".jpg"
          ".jpeg"
          ".png"
          ".webp"
        ]
      ) (builtins.readDir collection)
    )
  );
  chosen = lib.head images;
in
{
  config = lib.mkIf config.desktop.dms.enable {
    # Consumed by the session.json seeding in ./dms/default.nix.
    desktop.dms.initialWallpaper = "${collection}/${chosen}";

    home.extraOptions =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        # Symlink, not a copy: gives DMS's browser a *stable* path, since the
        # store path changes with every input update.
        home.file."Pictures/Wallpapers".source = collection;

        # Seeds DMS's last-browsed wallpaper folder (cache.json, not a
        # setting) so a fresh machine opens the browser here. Only written
        # when cache.json is absent — DMS rewrites it wholesale once you
        # browse elsewhere, so editing it later would just be undone.
        home.activation.seedDmsWallpaperFolder =
          let
            folder = "${config.home.homeDirectory}/Pictures/Wallpapers";
            seed = (pkgs.formats.json { }).generate "dms-cache-seed.json" {
              wallpaperLastPath = folder;
              profileLastPath = "";
              fileBrowserSettings.wallpaper = {
                lastPath = folder;
                viewMode = "grid";
                sortBy = "name";
                sortAscending = true;
                iconSizeIndex = 1;
                showSidebar = true;
              };
              configVersion = 2; # CacheData.qml cacheConfigVersion
            };
          in
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            cache="$HOME/.cache/DankMaterialShell/cache.json"
            if [ ! -e "$cache" ]; then
              run mkdir -p "$(dirname "$cache")"
              run install -m 644 ${seed} "$cache"
            fi
          '';
      };
  };
}
