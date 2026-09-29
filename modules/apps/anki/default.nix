{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.apps.anki;
  ankiAddons = import ./_lib { inherit pkgs lib; };
in
{
  options.apps.anki.enable = lib.mkEnableOption "Anki with a declaratively deployed addon set";

  config = lib.mkIf cfg.enable {
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
        addonsDir = "$HOME/.local/share/Anki2/addons21";
      in
      {
        home.packages = [
          # not pkgs.stable.anki: the desktop's Qt style plugins (QT_PLUGIN_PATH,
          # modules/theming/matugen.nix) are built against unstable's qtbase.
          # A stable/unstable qtbase mismatch sends QProxyStyle::standardPalette
          # into infinite recursion and Anki SIGSEGVs on startup.
          pkgs.anki
        ];

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
                file = ankiAddons.recolorBaseMeta;
              }
            ];
          }
        );
      };

    theming.matugen.templates.anki-recolor = {
      input = ankiAddons.recolorTemplate;
      output = "${config.users.users.otis.home}/.local/state/sitolamix/anki-recolor.json";
      postHook = "${ankiAddons.recolorApply}";
    };
  };
}
