_:
{
  flake.modules.nixos.gaming =
    { pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = false;
        gamescopeSession.enable = true;
      };
      programs.gamemode.enable = true;

      home.extraOptions = {
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
