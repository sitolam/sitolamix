{ config, lib, ... }:
let
  cfg = config.keyboard.kanata;
in
{
  options.keyboard.kanata.enable = lib.mkEnableOption "kanata home-row-mods keyboard remapping";

  config = lib.mkIf cfg.enable {
    services.kanata = {
      enable = true;
      keyboards.default = {
        devices = [ ];
        extraDefCfg = ''
          log-layer-changes no
          process-unmapped-keys yes
          concurrent-tap-hold yes
        '';
        config = builtins.readFile ./kanata-config.kbd;
      };
    };
  };
}
