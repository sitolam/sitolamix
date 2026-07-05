{ config, lib, ... }:
let
  cfg = config.suites.development;
in
{
  options.suites.development.enable = lib.mkEnableOption "development tooling (vscode, docker, k8s, ...)";

  config = lib.mkIf cfg.enable {
    apps.vscode.enable = true;
    apps.zed.enable = true;
    services.docker.enable = true;

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          k9s
          kubectl
          lazydocker
          dbeaver-bin
          bruno
          opentofu
          distrobox
          scrcpy
          claude-code
        ];
      };
  };
}
