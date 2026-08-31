{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.apps.stayfree;
in
{
  options.apps.stayfree.enable = lib.mkEnableOption "StayFree desktop (screen-time tracker / website blocker)";

  config = lib.mkIf cfg.enable {
    # StayFree is proprietary and absent from nixpkgs, so the packaging lives in
    # our own flake (see the `stayfree` input). The overlay builds the wrapped
    # AppImage against this config's nixpkgs rather than the input's.
    nixpkgs.overlays = [ inputs.stayfree.overlays.default ];

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.stayfree ];
      };
  };
}
