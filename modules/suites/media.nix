{ config, lib, ... }:
let
  cfg = config.suites.media;
in
{
  options.suites.media.enable = lib.mkEnableOption "media creation + playback apps";

  config = lib.mkIf cfg.enable {
    apps = {
      gpu-screen-recorder.enable = true;
      spotify.enable = true; # spotify via spicetify (themed + extensions)
      cliamp.enable = true; # Winamp 2.x TUI — config, Spotify provider, Mod+Alt+C
      ytdlp-download.enable = true; # right-click "Download with yt-dlp" in helium
    };

    home.extraOptions =
      { pkgs, ... }:
      let
        # Upscayl's Electron UI crashes on our NVIDIA + Wayland setup (GPU
        # process fails EGL init, glibc aborts on an out-of-range RT prio).
        # The actual upscaling runs on a bundled Vulkan ncnn binary, not the
        # Electron GPU process, so disabling the latter costs nothing.
        # symlinkJoin + a real wrapper so the .desktop entry picks up the flags.
        upscayl-wrapped = pkgs.symlinkJoin {
          name = "upscayl";
          paths = [ pkgs.upscayl ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            rm $out/bin/upscayl
            makeWrapper ${pkgs.upscayl}/bin/upscayl $out/bin/upscayl \
              --add-flags "--disable-gpu --in-process-gpu"
          '';
        };
      in
      {
        home.packages = with pkgs; [
          gimp
          inkscape
          upscayl-wrapped # AI image upscaler (Real-ESRGAN); gpu-disabled Electron UI
          kdePackages.kdenlive
          mpv
          vlc
          fladder # Jellyfin client
          loupe
          obs-studio
          noisetorch

          cava # audio visualiser; declared here so it isn't DMS's dependency
        ];
      };
  };
}
