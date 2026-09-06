{ config, lib, ... }:
let
  cfg = config.apps.ytdlp-download;

  # Chrome Web Store id of the yt-dlp companion extension, verified against
  # basecamp/omarchy's default/chromium/native-messaging-hosts manifest — the
  # same extension, just pointed at our own host below instead of theirs.
  extensionId = "dedjgknigfeelejglamclffonmophnfl";
  hostName = "com.sitolamix.ytdlp";
in
{
  options.apps.ytdlp-download.enable = lib.mkEnableOption "download videos via the yt-dlp browser extension";

  # Only reachable with apps.helium.enable too — that module carries the
  # extension's Web Store entry (see ../helium/default.nix). No assertion:
  # both are on by default (suites/media.nix, suites/browser.nix), and
  # without helium this module just installs a native-messaging host nothing
  # calls, which is harmless.

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
        # Helium's own profile dir (see ../helium/default.nix) — Chromium's
        # native-messaging lookup is per-profile under NativeMessagingHosts,
        # not the system-wide /etc/opt/chrome path this build of helium does
        # not read for anything but policies.
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
