{ config, inputs, ... }:
{
  flake.nixosConfigurations.gamingpc = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      # baseline
      config.flake.modules.nixos.base
      config.flake.modules.nixos.kernel
      config.flake.modules.nixos.grub

      # HM bridge (extraOptions alias)
      config.flake.modules.nixos.hm-integration

      # hardware
      config.flake.modules.nixos.gamingpc-hw
      config.flake.modules.nixos.audio
      config.flake.modules.nixos.bluetooth
      config.flake.modules.nixos.graphics
      config.flake.modules.nixos.nvidia
      inputs.nixos-hardware.nixosModules.common-cpu-amd
      inputs.nixos-hardware.nixosModules.common-pc
      inputs.nixos-hardware.nixosModules.common-pc-ssd

      # theming
      config.flake.modules.nixos.stylix

      # desktop
      config.flake.modules.nixos.niri
      config.flake.modules.nixos.noctalia
      config.flake.modules.nixos.kanata

      # services
      config.flake.modules.nixos.docker

      # bundles
      config.flake.modules.nixos.base-cli
      config.flake.modules.nixos.dev-cli
      config.flake.modules.nixos.browser
      config.flake.modules.nixos.media
      config.flake.modules.nixos.social
      config.flake.modules.nixos.school
      config.flake.modules.nixos.gaming

      # host-local settings
      {
        networking.hostName = "gamingpc";
        system.stateVersion = "25.11";

        home-manager.sharedModules = [
          inputs.noctalia.homeModules.default
          config.flake.modules.homeManager.shared
        ];

        # per-host monitors — HM niri outputs (aliased through extraOptions)
        home.extraOptions = {
          programs.niri.settings.outputs = {
            "DP-3" = {
              mode = {
                width = 1920;
                height = 1080;
                refresh = 60.000;
              };
              scale = 1.0;
              position = { x = 0; y = 0; };
              focus-at-startup = true;
            };
            "HDMI-A-1" = {
              mode = {
                width = 1920;
                height = 1080;
                refresh = 60.000;
              };
              scale = 1.0;
              position = { x = 1920; y = 0; };
            };
          };
        };
      }
    ];
  };
}
