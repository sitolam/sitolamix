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
    home.extraOptions.home.packages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.helium.defaultPackage.${pkgs.stdenv.hostPlatform.system}
    ];
  };
}
