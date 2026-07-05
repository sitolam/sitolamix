{ config, lib, ... }:
let
  cfg = config.suites.media;
in
{
  options.suites.media.enable = lib.mkEnableOption "media creation + playback apps";

  config = lib.mkIf cfg.enable {
    apps.gpu-screen-recorder.enable = true;

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          spotify
          gimp
          inkscape
          kdePackages.kdenlive
          mpv
          vlc
          loupe
          obs-studio
          noisetorch
        ];
      };
  };
}
