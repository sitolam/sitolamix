{
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  # Any NixOS module can write `home.extraOptions = { ... }` (attrset) or
  # `home.extraOptions = { config, ... }: { ... }` (function needing HM args).
  # All definitions from every file are merged into home-manager.users.otis,
  # so system + home-manager config live together in one file per feature.
  options.home.extraOptions = lib.mkOption {
    type = lib.types.deferredModule;
    default = { };
    description = "Home-manager config for user `otis`, merged from any NixOS module.";
  };

  config = {
    home.extraOptions = {
      home.stateVersion = config.system.stateVersion;
      xdg.enable = true;
    };

    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs; };
      users.otis = {
        imports = [ config.home.extraOptions ];
      };
    };
  };
}
