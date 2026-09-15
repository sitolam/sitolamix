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

          # mkForce: stylix's own spicetify target (still active elsewhere in
          # this repo) sets theme.name = "stylix" at the same priority. That
          # target's actual colour file is moot here — see the postFixup
          # symlink below, which replaces the built colors.css outright — but
          # the conflicting *theme* definition still fails evaluation without
          # this override. Drop it along with stylix.targets.spicetify itself
          # once stylix is removed (Task 7).
          theme = lib.mkForce spicePkgs.themes.sleek;
          # mkForce for the same reason as theme above: stylix's target sets
          # colorScheme = "base", which sleek's theme.sh doesn't define.
          # Value is otherwise moot — postFixup's symlink replaces the built
          # colors.css before Spotify ever reads it.
          colorScheme = lib.mkForce "TokyoNight";

          # Colours follow the wallpaper. spicetify bakes a colour scheme into
          # the store build at `spicetify apply` time, which no runtime change
          # can reach — but the result loads its colours from a separate
          # Apps/xpui/colors.css. So the build is left with sleek's default
          # scheme and that one file is replaced, after apply, by a link out
          # of the store to the file matugen renders from ./colors.css
          # (theming.matugen.templates.spotify below). Spotify reads it at
          # startup: a new wallpaper shows on the next launch. Checked
          # 2026-09-15 that Spotify's Chromium follows the link. Drop this if
          # spicetify-nix ever grows a runtime colour file of its own.
          spotifyPackage = pkgs.spotify.overrideAttrs (old: {
            postFixup = (old.postFixup or "") + ''
              ln -sf /home/otis/.config/spicetify-dms/colors.css $out/share/spotify/Apps/xpui/colors.css
            '';
          });
        };

        # niri bits live here rather than in niri/bindings.nix + niri/rules.nix
        # so the whole feature stays in one file; both option types merge.
        programs.niri.settings = lib.mkIf osConfig.desktop.niri.enable {
          # Mod+Alt+<letter> is the "run a tool" plane — see
          # ../desktop/niri/KEYBINDINGS.md. F because S (colour picker), P
          # (keydrill) and T (theme) are taken. Just opens Spotify as a
          # floating window wherever you currently are — no workspace
          # switching or pinning.
          binds."Mod+Alt+F".action.spawn = [ "spotify" ];

          window-rules = lib.mkAfter [
            {
              # both spellings, as in niri/rules.nix: the app-id has changed
              # case between spotify releases.
              matches = [
                { app-id = "^spotify$"; }
                { app-id = "^Spotify$"; }
              ];
              open-floating = true;
              # bigger than cliamp's float (0.6 × 0.6): this one is a full GUI
              # client with a sidebar, not a 24-row TUI.
              default-column-width.proportion = 0.75;
              default-window-height.proportion = 0.8;
            }
          ];
        };
      };

    theming.matugen.templates.spotify = {
      input = ./colors.css;
      output = "/home/otis/.config/spicetify-dms/colors.css";
    };
  };
}
