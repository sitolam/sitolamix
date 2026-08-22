{ config, lib, ... }:
let
  cfg = config.suites.school;
in
{
  options.suites.school.enable = lib.mkEnableOption "study / office apps";

  config = lib.mkIf cfg.enable {
    # Secrets for the two addons below whose config holds live credentials
    # (HyperTTS's Azure key, Anki Leaderboard's auth token) -- see
    # modules/suites/anki-addons/default.nix for why these can't just live in
    # the vendored/seeded config like everything else.
    sops.secrets.hypertts_azure_key = {
      sopsFile = ../../secrets/anki.yaml;
      owner = "otis";
      mode = "0400";
    };
    sops.secrets.anki_leaderboard_authtoken = {
      sopsFile = ../../secrets/anki.yaml;
      owner = "otis";
      mode = "0400";
    };

    home.extraOptions =
      { pkgs, lib, ... }:
      let
        # Same theme lookup as modules/desktop/dms/theme.nix -- the active
        # theme's `recolor` table drives ReColor's colors below.
        theme = (import ../../themes { inherit lib; }).get config.theming.stylix.theme;
        # Lives outside ./modules (repo root ../../anki-addons, like ../../themes)
        # so import-tree doesn't try to load it as a NixOS module.
        ankiAddons = import ../../anki-addons { inherit pkgs lib theme; };
        addonsDir = "$HOME/.local/share/Anki2/addons21";
      in
      {
        home.packages = with pkgs; [
          # unstable's anki 25.09.4 fails to build: its offline uv resolve dies
          # with "iniconfig was not found in the cache" (nixpkgs packaging bug,
          # not ours). The stable set has the same 25.09.4 and builds -- it
          # substitutes straight from cache.nixos.org. See
          # modules/system/nixpkgs-stable.nix; drop the `stable.` once unstable
          # is fixed.
          stable.anki
          antimicrox
          zotero
          onlyoffice-desktopeditors
          typst
          tinymist # Typst language server (LSP for editors)
        ];

        # Deploys every addon in ankiAddons.addons into the real addons21
        # folder on every activation (code only -- meta.json/user_files are
        # left alone once they exist, so GUI-made config changes survive
        # rebuilds). The two secret merges keep HyperTTS/Leaderboard synced
        # to sops regardless of anything else; ReColor's meta.json is fully
        # regenerated from the active theme every time (see anki-addons).
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
