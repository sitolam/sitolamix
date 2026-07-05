{ config, lib, ... }:
let
  cfg = config.apps.gparted;
in
{
  options.apps.gparted.enable = lib.mkEnableOption "GParted partition editor";

  config = lib.mkIf cfg.enable {
    # gparted elevates itself via pkexec at runtime; the package is enough.
    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.gparted ];
      };
  };
}
