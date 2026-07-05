{ config, lib, ... }:
let
  cfg = config.suites.gaming;
in
{
  options.suites.gaming.enable = lib.mkEnableOption "Steam + game launchers";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      gamescopeSession.enable = true;
    };
    programs.gamemode.enable = true;

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          protontricks
          protonup-qt
          lutris
          prismlauncher
          heroic
          gamescope
        ];
      };
  };
}
