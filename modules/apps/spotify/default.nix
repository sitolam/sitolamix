{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.apps.spotify;
in
{
  options.apps.spotify.enable = lib.mkEnableOption "Spotify with spicetify (wallpaper-themed + extensions)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      {
        osConfig,
        pkgs,
        lib,
        ...
      }:
      let
        spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      in
      {
        imports = [ inputs.spicetify-nix.homeManagerModules.default ];

        programs.spicetify = {
          enable = true;

          enabledExtensions = with spicePkgs.extensions; [
            shuffle
            groupSession # listen-along links
            powerBar # spotlight-style search
            songStats
            history
            skipOrPlayLikedSongs
            goToSong
            playlistIntersection
            playNext
          ];

          enabledCustomApps = with spicePkgs.apps; [
            marketplace
            localFiles
            lyricsPlus # scrolling lyrics
          ];

          theme = spicePkgs.themes.sleek;

          # spicetify bakes colours into the store build at apply time, which
          # no runtime change can reach, but reads Apps/xpui/colors.css
          # separately — symlink that to matugen's rendered file instead.
          # Drop if spicetify-nix ever grows a runtime colour file of its own.
          spotifyPackage = pkgs.spotify.overrideAttrs (old: {
            # hardcoded, not osConfig.users.users.otis.home: this splices into
            # the store derivation's postFixup, so the path can't depend on
            # the evaluating user
            postFixup = (old.postFixup or "") + ''
              ln -sf /home/otis/.config/spicetify-dms/colors.css $out/share/spotify/Apps/xpui/colors.css
            '';
          });
        };

        # niri bits live here, not niri/bindings.nix + niri/rules.nix, so the
        # whole feature stays in one file
        programs.niri.settings = lib.mkIf osConfig.desktop.niri.enable {
          binds."Mod+Alt+F".action.spawn = [ "spotify" ]; # F because S/P/T are taken

          window-rules = lib.mkAfter [
            {
              matches = [
                # app-id case has changed between spotify releases
                { app-id = "^spotify$"; }
                { app-id = "^Spotify$"; }
              ];
              open-floating = true;
              default-column-width.proportion = 0.75; # bigger than cliamp's float
              default-window-height.proportion = 0.8;
            }
          ];
        };
      };

    theming.matugen.templates.spotify = {
      input = ./colors.css;
      output = "${config.users.users.otis.home}/.config/spicetify-dms/colors.css";
    };
  };
}
