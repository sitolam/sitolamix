{ config, lib, ... }:
let
  cfg = config.apps.cliamp;

  # wrapper below reads the decrypted secret at launch
  clientIdPath = config.sops.secrets.cliamp_spotify_client_id.path;

  # Written to $HOME by activation, not symlinked, because cliamp rewrites
  # this file itself on every shuffle/repeat/theme/EQ change; runtime toggles
  # survive until the next rebuild. client_id expands from the environment
  # (cliamp's config.parseString), so the secret never enters the nix store.
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
        # a wrapper is the only place that can set client_id for every launch route
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
          pkgs.pulseaudio # cliamp's audio-device picker shells out to pactl
        ];

        home.activation.cliampConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p "$HOME/.config/cliamp"
          run install -m 0600 ${configFile} "$HOME/.config/cliamp/config.toml"
        '';

        # niri bits live here, not niri/bindings.nix + niri/rules.nix, so the
        # whole feature stays in one file
        programs.niri.settings = lib.mkIf config.desktop.niri.enable {
          binds."Mod+Alt+C".action.spawn = [
            # Mod+Alt+<letter> is the "run a tool" plane
            "ghostty"
            "--class=com.mitchellh.ghostty.cliamp"
            "-e"
            "cliamp"
          ];

          window-rules = lib.mkAfter [
            {
              matches = [ { app-id = "^com\\.mitchellh\\.ghostty\\.cliamp$"; } ]; # --class above is the only match
              open-floating = true;
              default-column-width.proportion = 0.6; # niri centres a floating window; size is all we set
              default-window-height.proportion = 0.6;
            }
          ];
        };
      };
  };
}
