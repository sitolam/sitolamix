_:
{
  flake.modules.nixos.kanata = {
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
