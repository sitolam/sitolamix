{ inputs, ... }:
{
  flake.modules.nixos.browser =
    { pkgs, ... }:
    {
      home.extraOptions = {
        home.packages = [
          inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
          inputs.helium.defaultPackage.${pkgs.stdenv.hostPlatform.system}
        ];
      };
    };
}
