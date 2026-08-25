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

    home.extraOptions.home.packages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
