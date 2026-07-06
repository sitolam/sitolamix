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
  options.apps.spotify.enable = lib.mkEnableOption "Spotify with spicetify (stylix-themed + extensions)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      {
        config,
        pkgs,
        ...
      }:
      let
        spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      in
      {
        imports = [ inputs.spicetify-nix.homeManagerModules.default ];

        # stylix auto-enables its own spicetify target; disable it so our
        # customColorScheme (below) is the single source of theming.
        # (spotify is unfree, already allowed via nixpkgs.config.allowUnfree in
        # modules/system/nix.nix + home-manager.useGlobalPkgs.)
        stylix.targets.spicetify.enable = false;

        programs.spicetify = {
          enable = true;

          enabledExtensions = with spicePkgs.extensions; [
            shuffle # true shuffle
            groupSession # listen-along links
            powerBar # spotlight-style search
            songStats # per-song stats
            history # listening history page
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
          colorScheme = "custom";
          # themed from the active stylix scheme (base16 named colours, no '#').
          customColorScheme = with config.lib.stylix.colors; {
            text = magenta;
            subtext = base05;
            nav-active-text = bright-green;
            main = base00;
            sidebar = base00;
            player = base00;
            card = base00;
            shadow = base02;
            main-secondary = base01;
            button = orange;
            button-secondary = bright-cyan;
            button-active = orange;
            button-disabled = base0D;
            nav-active = magenta;
            play-button = green;
            tab-active = yellow;
            notification = blue;
            notification-error = red;
            playback-bar = bright-green;
            misc = bright-magenta;
          };
        };
      };
  };
}
