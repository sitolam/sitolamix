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

        # DMS renders ~/.config/vesktop/themes/dank-discord.css from the wallpaper;
        # Vesktop only loads a theme listed in its own settings, which it owns and
        # rewrites, so the name is merged in rather than the file written.
        home.activation.vesktopDmsTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          s="$HOME/.config/vesktop/settings/settings.json"
          if [ -e "$s" ]; then
            run ${pkgs.jq}/bin/jq '.enabledThemes = ((.enabledThemes // []) + ["dank-discord.css"] | unique)' "$s" > "$s.tmp"
            run mv "$s.tmp" "$s"
          fi
        '';
      };
  };
}
