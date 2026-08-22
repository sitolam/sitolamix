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
      (inputs.helium.helium.${pkgs.stdenv.hostPlatform.system} {
        # FHS/AppImage sandbox drops the niri-set ozone env vars, so helium
        # falls back to Xwayland where touchpad scroll is discrete/jumpy
        # instead of the smooth, niri-scaled wayland axis events. Force
        # native wayland + smooth scrolling explicitly instead.
        commandLineArgs = [
          "--ozone-platform=wayland"
          "--enable-smooth-scrolling"
        ];
      })
    ];
  };
}
