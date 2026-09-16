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

        # This activation is feature work living in a suite rather than its
        # own module — deliberately, for now: vesktop is a bare
        # `home.packages` entry above with no options and nothing else to
        # gate, so a whole `modules/apps/vesktop.nix` would exist only to
        # hold this one activation. It becomes its own module the day
        # vesktop grows a second concern.
        #
        # DMS renders ~/.config/vesktop/themes/dank-discord.css from the wallpaper;
        # Vesktop only loads a theme listed in its own settings, which it owns and
        # rewrites, so the name is merged in rather than the file written.
        home.activation.vesktopDmsTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          s="$HOME/.config/vesktop/settings/settings.json"
          if [ -e "$s" ]; then
            # `&&`, not two separate `run`s: a jq failure must not fall
            # through to `mv` and install a truncated file over Vesktop's
            # live settings.
            run sh -c '${pkgs.jq}/bin/jq "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"' \
              -- '.enabledThemes = ((.enabledThemes // []) + ["dank-discord.css"] | unique)' "$s"
          fi
        '';
      };
  };
}
