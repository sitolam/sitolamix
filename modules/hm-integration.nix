{ inputs, ... }:
{
  flake.modules.nixos.hm-integration =
    {
      options,
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];

      options.home.extraOptions = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Home-manager config for user `otis`. Any NixOS module can write to this; the definitions are aliased into `home-manager.users.otis` verbatim.";
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
          users.otis = lib.mkAliasDefinitions options.home.extraOptions;
        };
      };
    };
}
