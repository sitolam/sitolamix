{ config, lib, ... }:
let
  cfg = config.apps.localsend;
in
{
  options.apps.localsend.enable = lib.mkEnableOption "LocalSend (LAN AirDrop-alike)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.localsend ];
      };
  };
}
