{ config, lib, ... }:
let
  cfg = config.suites.development;
in
{
  options.suites.development.enable = lib.mkEnableOption "development tooling (vscode, docker, k8s, ...)";

  config = lib.mkIf cfg.enable {
    apps = {
      claude-code.enable = true;
      vscode.enable = true;
      zed.enable = true;
      android.enable = true;
    };
    services.docker.enable = true;

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          k9s
          kubectl
          lazydocker
          opentofu
          distrobox
        ];
      };
  };
}
