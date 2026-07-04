_:
{
  flake.modules.nixos.media =
    { pkgs, ... }:
    {
      home.extraOptions = {
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
