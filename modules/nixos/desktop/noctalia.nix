{ inputs, ... }:
{
  flake.modules.nixos.noctalia =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}
