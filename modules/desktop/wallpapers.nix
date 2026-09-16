{
  config,
  lib,
  inputs,
  ...
}:
let
  # dharmx/walls — a flake input, so the images live in the Nix store and
  # nowhere else, sorted into category folders.
  collection = inputs.wallpapers;

  # The category DMS starts in. DMS has no wallpaper-folder setting:
  # Services/WallpaperCyclingService.qml cycles the directory of the current
  # wallpaper —
  #
  #   const wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'))
  #
  # — so seeding an image inside `nature/` makes cycling cover that category.
  # Pick an image from another folder in DMS to cycle that one instead.
  category = "nature";

  # First image of the category, by natural sort. Plain readDir on a store
  # path, so no import-from-derivation; guards against an input update
  # renaming files.
  images = lib.naturalSort (
    lib.attrNames (
      lib.filterAttrs (
        name: type:
        type == "regular"
        && lib.any (ext: lib.hasSuffix ext (lib.toLower name)) [
          ".jpg"
          ".jpeg"
          ".png"
        ]
      ) (builtins.readDir "${collection}/${category}")
    )
  );
  chosen = lib.head images;
in
{
  config = lib.mkIf config.desktop.dms.enable {
    # Consumed by the session.json seeding in ./dms/default.nix.
    desktop.dms.initialWallpaper = "${collection}/${category}/${chosen}";

    home.extraOptions =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        # `home.file` with a directory source symlinks the store path — it does
        # not copy. ~/Pictures/Wallpapers is a pointer costing no disk; it exists
        # only so DMS's browser has a *stable* path, since the store path changes
        # with every input update.
        home.file."Pictures/Wallpapers".source = collection;

        # Open DMS's wallpaper browser there on a fresh machine. DMS keeps the
        # last browsed directory in its *cache* (Common/CacheData.qml ->
        # cache.json) rather than in settings, so it cannot be a declared
        # setting — but the cache can be seeded, exactly like session.json.
        #
        # Only written when cache.json is absent, i.e. before DMS has ever run.
        # DMS holds this file in memory and rewrites it wholesale when you browse
        # elsewhere, so editing it underneath a running shell would just be
        # undone — and would fight a folder you had deliberately picked.
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
