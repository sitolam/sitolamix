{ config, lib, ... }:
let
  cfg = config.apps.cliamp;

  # sops decrypts to /run/secrets/<name>; the wrapper below reads it at launch.
  clientIdPath = config.sops.secrets.cliamp_spotify_client_id.path;

  # cliamp's config.toml. It is written to $HOME by the activation script rather
  # than symlinked from the store: cliamp rewrites this file itself whenever you
  # toggle shuffle/repeat, pick a theme, change the visualiser or save an EQ
  # curve (config.Save in the upstream source), and a read-only store symlink
  # would either break those writes or be replaced by a real file behind
  # home-manager's back. The file is ours (see CLAUDE.md): runtime toggles
  # survive until the next rebuild, then these values win again.
  #
  # client_id is *not* the literal ID: cliamp expands a value of exactly
  # "${NAME}" from the environment (config.parseString), so the secret stays in
  # /run/secrets and never enters the nix store. If the variable is unset the
  # expansion yields "", and cliamp falls back to its built-in librespot
  # client_id — degraded (shared rate-limit quota), not broken.
  configFile = builtins.toFile "cliamp-config.toml" ''
    # Managed by modules/apps/cliamp.nix — edits here are overwritten on rebuild.

    # Highest-fidelity audio path cliamp offers: sample_rate/resample_quality/
    # bit_depth are the documented maxima. buffer_ms is deliberately *not* — it
    # is latency, not quality, and the 5000 maximum means ~5s before playback
    # starts or a seek lands. 250 is upstream's default; raise it toward 2000
    # only if a radio stream underruns.
    sample_rate = 192000
    buffer_ms = 250
    resample_quality = 4
    bit_depth = 32

    visualizer = "BarsDot"
    provider = "spotify"

    # A [spotify] section is what registers the provider at all; client_id only
    # swaps the built-in fallback for our own developer app. Requires Spotify
    # Premium. 320 is the top bitrate Spotify serves.
    [spotify]
    client_id = "''${CLIAMP_SPOTIFY_CLIENT_ID}"
    bitrate = 320
  '';
in
{
  options.apps.cliamp.enable = lib.mkEnableOption "cliamp — Winamp 2.x as a TUI music player";

  config = lib.mkIf cfg.enable {
    sops.secrets.cliamp_spotify_client_id = {
      sopsFile = ../../secrets/cliamp.yaml;
      owner = "otis";
      mode = "0400";
    };

    home.extraOptions =
      { pkgs, lib, ... }:
      let
        # cliamp reads the client_id out of the environment; a wrapper is the
        # only place that can put it there for every launch route (terminal,
        # the niri bind below, the .desktop entry).
        cliamp-wrapped = pkgs.symlinkJoin {
          name = "cliamp-wrapped";
          paths = [ pkgs.cliamp ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            rm $out/bin/cliamp
            makeWrapper ${pkgs.cliamp}/bin/cliamp $out/bin/cliamp \
              --run 'export CLIAMP_SPOTIFY_CLIENT_ID="$(cat ${clientIdPath} 2>/dev/null || true)"'
          '';
        };
      in
      {
        home.packages = [
          cliamp-wrapped
          # cliamp's audio-device picker (and its sink switching) shells out to
          # `pactl` — see player/audio_device_linux.go. Nothing else here
          # installs it: niri/bindings.nix deliberately uses wpctl because this
          # system had no pulseaudio-utils at all. pipewire-pulse answers pactl
          # fine, we just need the client binary.
          pkgs.pulseaudio
        ];

        home.activation.cliampConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p "$HOME/.config/cliamp"
          run install -m 0600 ${configFile} "$HOME/.config/cliamp/config.toml"
        '';

        # niri bits live here rather than in niri/bindings.nix + niri/rules.nix
        # so the whole feature stays in one file; both option types merge.
        programs.niri.settings = lib.mkIf config.desktop.niri.enable {
          # Mod+Alt+<letter> is the "run a tool" plane — see
          # ../desktop/niri/KEYBINDINGS.md. The window rule below pins cliamp to
          # the "music" workspace (declared in ../desktop/niri/layout.nix)
          # wherever it is launched from; the bind focuses that workspace too,
          # so pressing it takes you there rather than leaving the window
          # somewhere off-screen.
          binds."Mod+Alt+C".action.spawn = [
            "sh"
            "-c"
            "niri msg action focus-workspace music; exec ghostty --class=com.mitchellh.ghostty.cliamp -e cliamp"
          ];

          window-rules = lib.mkAfter [
            {
              # --class above is the only reason this matches: every other
              # ghostty window is com.mitchellh.ghostty.
              matches = [ { app-id = "^com\\.mitchellh\\.ghostty\\.cliamp$"; } ];
              open-on-workspace = "music";
              open-floating = true;
              # niri centres a floating window it opens with no stored position,
              # so size is all we set.
              default-column-width.proportion = 0.6;
              default-window-height.proportion = 0.6;
            }
          ];
        };
      };
  };
}
