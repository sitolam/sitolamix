{ config, lib, ... }:
let
  cfg = config.apps.nitch;
in
{
  options.apps.nitch.enable = lib.mkEnableOption "nitch system fetch";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.nitch ];

        # run nitch on opening a terminal (fish greeting). Guarded on fish being
        # enabled so this module stays self-contained.
        programs.fish.functions.fish_greeting = lib.mkIf config.apps.fish.enable ''
          command -q nitch; and nitch
        '';
      };
  };
}
