_:
{
  flake.modules.nixos.social =
    { pkgs, ... }:
    {
      home.extraOptions = {
        home.packages = with pkgs; [
          signal-desktop
          vesktop
          element-desktop
        ];
      };
    };
}
