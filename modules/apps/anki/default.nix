{ config, lib, ... }:
let
  cfg = config.apps.anki;
in
{
  options.apps.anki.enable = lib.mkEnableOption "Anki with a declaratively deployed addon set";

  config = lib.mkIf cfg.enable {
    # Secrets for the two addons whose config holds live credentials
    # (HyperTTS's Azure key, Anki Leaderboard's auth token) — see ./_lib for
    # why these can't just live in the vendored/seeded config like everything
    # else.
    sops.secrets.hypertts_azure_key = {
      sopsFile = ../../../secrets/anki.yaml;
      owner = "otis";
      mode = "0400";
    };
    sops.secrets.anki_leaderboard_authtoken = {
      sopsFile = ../../../secrets/anki.yaml;
      owner = "otis";
      mode = "0400";
    };

    home.extraOptions =
      { pkgs, lib, ... }:
      let
        # Same theme lookup as modules/desktop/dms/theme.nix — the active
        # theme's `recolor` table drives ReColor's colors below.
        theme = (import ../../../themes { inherit lib; }).get config.theming.stylix.theme;
        # ./_lib is the addon tree (sources, seeds, patches) plus the builder.
        # import-tree skips any path containing `/_`, so it is *not* loaded as
        # a NixOS module even though it lives under modules/.
        ankiAddons = import ./_lib { inherit pkgs lib theme; };
        addonsDir = "$HOME/.local/share/Anki2/addons21";
      in
      {
        home.packages = [
          # Deliberately the unstable package, not pkgs.stable.anki. It was on
          # stable from 2026-08-05, when unstable's anki 25.09.4 failed its
          # offline uv resolve ("iniconfig was not found in the cache"); that
          # is fixed upstream and unstable is on 26.08, so the pin is gone.
          #
          # Keeping it would now break Anki outright rather than merely cost a
          # second closure. Anki is a Qt app and this desktop themes Qt through
          # QT_PLUGIN_PATH (kvantum + qt6ct, which stylix's own Qt support puts
          # there — no file in this repo sets them): those style plugins are
          # built against the *unstable* qtbase, and stable's anki
          # carried its own older one (6.11.1 against the system's 6.11.2 on
          # 2026-09-03). Loading a style plugin linked to a second Qt into the
          # process sends QProxyStyle::standardPalette into infinite recursion
          # and Anki dies on startup with SIGSEGV before showing a window.
          #
          # So if anki ever has to go back to pkgs.stable, the two qtbase
          # versions have to match, or the theming env has to be stripped for
          # this one app.
          pkgs.anki
        ];

        # Deploys every addon in ankiAddons.addons into the real addons21
        # folder on every activation (code only — meta.json/user_files are
        # left alone once they exist, so GUI-made config changes survive
        # rebuilds). The two secret merges keep HyperTTS/Leaderboard synced
        # to sops regardless of anything else; ReColor's meta.json is fully
        # regenerated from the active theme every time (see ./_lib).
        home.activation.ankiAddons = lib.hm.dag.entryAfter [ "writeBoundary" ] (
          ankiAddons.mkActivationScript {
            inherit addonsDir;
            secretMerges = [
              {
                id = "111623432";
                jqPath = ".configuration.service_config.Azure.api_key";
                secretPath = config.sops.secrets.hypertts_azure_key.path;
              }
              {
                id = "175794613";
                jqPath = ".authToken";
                secretPath = config.sops.secrets.anki_leaderboard_authtoken.path;
              }
            ];
            themedFiles = [
              {
                id = "688199788";
                file = ankiAddons.recolorMetaFile;
              }
            ];
          }
        );
      };
  };
}
