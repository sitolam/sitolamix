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

        # This activation is feature work living in a suite rather than its
        # own module — deliberately, for now: zen is a bare `home.packages`
        # entry above with no options and nothing else to gate, so a whole
        # `modules/apps/zen.nix` would exist only to hold this one activation.
        # The day zen grows a second concern (flags, policies, an extension
        # set — the shape helium.nix already has), split it out then.
        #
        # zen: DMS renders ~/.config/DankMaterialShell/zen.css from the wallpaper.
        # zen only loads chrome/userChrome.css with the legacy stylesheet pref on,
        # and profile directories are created by zen itself under a random name, so
        # link into every profile that exists. A fresh machine picks this up on the
        # first rebuild after zen has been started once. Drop this if zen-browser's
        # flake grows a home-manager module with profile settings (then use that).
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
