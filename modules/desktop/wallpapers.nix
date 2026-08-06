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
