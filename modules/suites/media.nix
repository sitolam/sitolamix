{ config, lib, ... }:
let
  cfg = config.suites.media;
in
{
  options.suites.media.enable = lib.mkEnableOption "media creation + playback apps";

  config = lib.mkIf cfg.enable {
    apps.gpu-screen-recorder.enable = true;
    apps.spotify.enable = true; # spotify via spicetify (themed + extensions)

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
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
