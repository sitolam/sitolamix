{ config, lib, ... }:
let
  cfg = config.apps.ytdlp-download;

  # Chrome Web Store id of the yt-dlp companion extension, verified against
  # basecamp/omarchy's native-messaging-hosts manifest.
  extensionId = "dedjgknigfeelejglamclffonmophnfl";
  hostName = "com.sitolamix.ytdlp";
in
{
  options.apps.ytdlp-download.enable = lib.mkEnableOption "download videos via the yt-dlp browser extension";

  # Only useful with apps.helium.enable too (carries the extension's Web
  # Store entry). No assertion: without helium this just installs an unused
  # native-messaging host, harmlessly.

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      let
        host = pkgs.writeShellApplication {
          name = "${hostName}-host";
          runtimeInputs = with pkgs; [
            yt-dlp
            ffmpeg
            jq
            libnotify
            mpv
            coreutils # realpath, mktemp, timeout
            util-linux # setsid
          ];
          text = builtins.readFile ./ytdlp-host.sh;
        };
      in
      {
        # Per-profile path: this helium build only reads /etc/opt/chrome for
        # policies, not native-messaging hosts.
        home.file.".config/net.imput.helium/NativeMessagingHosts/${hostName}.json".text = builtins.toJSON {
          name = hostName;
          description = "yt-dlp download host";
          path = lib.getExe host;
          type = "stdio";
          allowed_origins = [ "chrome-extension://${extensionId}/" ];
        };
      };
  };
}
