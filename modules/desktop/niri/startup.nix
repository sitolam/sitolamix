{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.niri.enable {
    home.extraOptions.programs.niri.settings.spawn-at-startup = [
      { command = [ "xwayland-satellite" ]; }
      { command = [ "kdeconnectd" ]; }
      {
        command = [
          "wl-clip-persist"
          "--clipboard"
          "regular"
        ];
      }
    ];
  };
}
