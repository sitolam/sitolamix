{ config, lib, ... }:
let
  cfg = config.suites.social;
in
{
  options.suites.social.enable = lib.mkEnableOption "chat / social apps";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, lib, ... }:
      {
        home.packages = with pkgs; [
          signal-desktop
          vesktop
          fluffychat
        ];

        # Lives here rather than apps/vesktop.nix since vesktop is a bare
        # `home.packages` entry with nothing else to gate.
        #
        # DMS renders ~/.config/vesktop/themes/dank-discord.css; Vesktop owns
        # and rewrites settings.json wholesale on exit, so merge the theme
        # name in rather than write the file, and skip while Vesktop is
        # running (a merge then is lost the moment it quits) — it takes
        # effect on the first rebuild done while Vesktop is closed. Match on
        # --user-data-dir since every Vesktop process shows as bare `electron`.
        home.activation.vesktopDmsTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          s="$HOME/.config/vesktop/settings/settings.json"
          if [ -e "$s" ] && ! ${pkgs.procps}/bin/pgrep -f -- "--user-data-dir=$HOME/.config/vesktop" >/dev/null; then
            # `&&`, not two `run`s: a jq failure must not fall through to
            # `mv` and install a truncated file.
            run sh -c '${pkgs.jq}/bin/jq "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"' \
              -- '.enabledThemes = ((.enabledThemes // []) + ["dank-discord.css"] | unique)' "$s"
          fi
        '';
      };
  };
}
