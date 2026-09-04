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

        # niri bits live here rather than in niri/bindings.nix + niri/rules.nix
        # so the whole feature stays in one file; both option types merge.
        programs.niri.settings = lib.mkIf osConfig.desktop.niri.enable {
          # Mod+Alt+<letter> is the "run a tool" plane — see
          # ../desktop/niri/KEYBINDINGS.md. F because S (colour picker), P
          # (keydrill) and T (theme) are taken. Same shape as cliamp's
          # Mod+Alt+C: focus the music workspace, then launch — the rule below
          # pins the window there wherever it was started from.
          binds."Mod+Alt+F".action.spawn = [
            "sh"
            "-c"
            "niri msg action focus-workspace music; exec spotify"
          ];

          window-rules = lib.mkAfter [
            {
              # both spellings, as in niri/rules.nix: the app-id has changed
              # case between spotify releases.
              matches = [
                { app-id = "^spotify$"; }
                { app-id = "^Spotify$"; }
              ];
              open-on-workspace = "music";
              open-floating = true;
              # bigger than cliamp's float (0.6 × 0.6): this one is a full GUI
              # client with a sidebar, not a 24-row TUI.
              default-column-width.proportion = 0.75;
              default-window-height.proportion = 0.8;
            }
          ];
        };
      };
  };
}
