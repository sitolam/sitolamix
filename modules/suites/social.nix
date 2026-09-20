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
        #
        # Skipped while Vesktop is running: Vesktop owns settings.json and
        # rewrites it wholesale on exit, so a merge written underneath a
        # running instance is silently lost the moment it quits — observed
        # live, `enabledThemes` came back `[]` and the theme showed as
        # present-but-disabled in Vesktop's own UI. Consequence: the theme
        # only actually enables on the first rebuild done while Vesktop is
        # closed.
        #
        # Vesktop has no `vesktop`-named process to `pgrep -x` — `bin/vesktop`
        # is a wrapper script that `exec`s the generic electron binary, so
        # every one of its processes (main, gpu, renderer, utility) shows up
        # in `ps` as bare `electron`, indistinguishable by name from any other
        # Electron app (confirmed by reading the built package's wrapper and
        # by inspecting `ps aux` while Vesktop was running). Match on its
        # `--user-data-dir`, which is Vesktop's own profile path and does not
        # change across versions, instead.
        home.activation.vesktopDmsTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          s="$HOME/.config/vesktop/settings/settings.json"
          if [ -e "$s" ] && ! ${pkgs.procps}/bin/pgrep -f -- "--user-data-dir=$HOME/.config/vesktop" >/dev/null; then
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
