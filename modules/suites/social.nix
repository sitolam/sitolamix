{ config, lib, ... }:
let
  cfg = config.suites.social;
in
{
  options.suites.social.enable = lib.mkEnableOption "chat / social apps";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          signal-desktop
          vesktop
          fluffychat
        ];
      };
  };
}
