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
    # Proprietary, absent from nixpkgs; packaged in our own `stayfree` input,
    # overlay builds the wrapped AppImage against this config's nixpkgs.
    nixpkgs.overlays = [ inputs.stayfree.overlays.default ];

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.stayfree ];
      };
  };
}
