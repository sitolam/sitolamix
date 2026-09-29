{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.suites.browser;
in
{
  options.suites.browser.enable = lib.mkEnableOption "web browsers (zen, helium)";

  config = lib.mkIf cfg.enable {
    # helium carries flags, policies and an extension set, so it has its own
    # module rather than a bare package entry here.
    apps.helium.enable = true;

    home.extraOptions =
      { lib, pkgs, ... }:
      {
        home.packages = [
          inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];

        # Lives here rather than its own apps/zen.nix since zen is a bare
        # `home.packages` entry with nothing else to gate. Split out if zen
        # grows a second concern (flags, policies, an extension set).
        #
        # DMS renders ~/.config/DankMaterialShell/zen.css. zen only loads
        # userChrome.css with the legacy stylesheet pref on, and creates its
        # profile dir under a random name itself, so link into every profile
        # found — picked up on the first rebuild after zen has run once.
        home.activation.zenDmsChrome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          for root in "$HOME/.zen" "$HOME/.config/zen"; do
            [ -d "$root" ] || continue
            for profile in "$root"/*/; do
              [ -e "$profile/prefs.js" ] || continue
              run mkdir -p "$profile/chrome"
              f="$profile/chrome/userChrome.css"
              # Skip a userChrome.css the user wrote by hand: ln -sfn would
              # silently replace it with the DMS symlink.
              [ -f "$f" ] && [ ! -L "$f" ] && continue
              run ln -sfn "$HOME/.config/DankMaterialShell/zen.css" "$f"
              if ! grep -q 'legacyUserProfileCustomizations.stylesheets' "$profile/user.js" 2>/dev/null; then
                run sh -c "echo 'user_pref(\"toolkit.legacyUserProfileCustomizations.stylesheets\", true);' >> '$profile/user.js'"
              fi
            done
          done
        '';
      };
  };
}
