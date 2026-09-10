{
  config,
  lib,
  inputs,
  pkgs,
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
    # Desktop counterpart the Bitwarden Helium extension needs for biometric
    # (system-authentication) unlock — see modules/apps/bitwarden.nix.
    apps.bitwarden.enable = true;

    home.extraOptions.home.packages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
