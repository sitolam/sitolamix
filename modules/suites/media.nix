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
    };

    home.extraOptions =
      { pkgs, ... }:
      let
        # Upscayl's Electron UI crashes on our NVIDIA + Wayland setup:
        #   libEGL: failed to create dri2 screen  (GPU process can't init EGL)
        #   Fatal glibc error: tpp.c:83 __pthread_tpp_change_priority  (SIGABRT)
        # The Chromium GPU thread requests an out-of-range RT scheduling prio and
        # glibc aborts. The actual upscaling runs on a bundled Vulkan ncnn binary,
        # not the Electron GPU process, so disabling the latter costs nothing.
        # symlinkJoin + a real wrapper so the .desktop (Exec=upscayl, PATH-resolved)
        # also picks up the flags.
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

          # cava: audio visualiser. DMS already pulls it in for the bar widget,
          # declared here so it does not depend on someone else's module.
          cava
        ];
      };
  };
}
