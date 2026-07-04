_:
{
  flake.modules.nixos.dev-cli =
    { pkgs, ... }:
    {
      home.extraOptions = {
        home.packages = with pkgs; [
          k9s
          kubectl
          lazydocker
          dbeaver-bin
          bruno
          opentofu
          distrobox
          scrcpy
        ];
      };
    };
}
