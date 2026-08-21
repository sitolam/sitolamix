{ config, lib, ... }:
let
  # default handler per category -> its .desktop id
  browser = "helium.desktop";
  fileManager = "org.gnome.Nautilus.desktop";
  video = "mpv.desktop";
  image = "org.gnome.Loupe.desktop";

  forMimes = app: mimes: lib.genAttrs mimes (_: app);
in
{
  config = lib.mkIf config.desktop.niri.enable {
    home.extraOptions = {
      # Declare the standard XDG user directories. Generates ~/.config/
      # user-dirs.dirs and creates the folders, which Nautilus reads to populate
      # its sidebar (Documents, Downloads, Music, Pictures, Videos). These match
      # what xdg-user-dirs-update already created, now managed declaratively.
      xdg.userDirs = {
        enable = true;
        createDirectories = true;
        # home-manager flipped this default to false for stateVersion >= 26.05
        # and warns until it is set explicitly. Pinned to the legacy `true` we
        # already run on: it exports XDG_DOCUMENTS_DIR & co into the session, so
        # apps launched from niri (not just ones that read user-dirs.dirs) still
        # resolve the folders.
        setSessionVariables = true;
      };

      # Default applications. NB: makes ~/.config/mimeapps.list HM-managed
      # (read-only) — change a default here, not via an app's "set as default".
      xdg.mimeApps = {
        enable = true;
        defaultApplications =
          forMimes browser [
            "text/html"
            "application/xhtml+xml"
            "application/pdf" # open PDFs in the browser

            "x-scheme-handler/http"
            "x-scheme-handler/https"
            "x-scheme-handler/about"
            "x-scheme-handler/unknown"
          ]
          // forMimes fileManager [ "inode/directory" ]
          // forMimes video [
            "video/mp4"
            "video/x-matroska"
            "video/webm"
            "video/quicktime"
            "video/x-msvideo"
            "video/mpeg"
            "video/x-flv"
            "video/3gpp"
            "video/ogg"
            "video/x-ms-wmv"
          ]
          // forMimes image [
            "image/png"
            "image/jpeg"
            "image/gif"
            "image/webp"
            "image/tiff"
            "image/bmp"
            "image/avif"
            "image/heif"
          ];
      };

      # Folder shortcuts in Nautilus's sidebar. Nautilus doesn't reliably surface
      # the XDG special dirs on its own here, so add them as GTK bookmarks
      # (~/.config/gtk-3.0/bookmarks, which Nautilus reads).
      gtk.gtk3.bookmarks = [
        "file://${config.users.users.otis.home}/Documents Documents"
        "file://${config.users.users.otis.home}/Downloads Downloads"
        "file://${config.users.users.otis.home}/Music Music"
        "file://${config.users.users.otis.home}/Pictures Pictures"
        "file://${config.users.users.otis.home}/Videos Videos"
      ];
    };
  };
}
