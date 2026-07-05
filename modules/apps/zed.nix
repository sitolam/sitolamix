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
        };
      };
  };
}
