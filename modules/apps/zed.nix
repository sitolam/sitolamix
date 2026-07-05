{ config, lib, ... }:
let
  cfg = config.apps.zed;
in
{
  options.apps.zed.enable = lib.mkEnableOption "Zed editor";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        programs.zed-editor = {
          enable = true;
          package = pkgs.zed-editor;
          # stylix's zed target sets the theme + fonts in userSettings; this
          # merges with it (different keys).
          userSettings = {
            vim_mode = true;
          };
        };
      };
  };
}
