{ config, lib, ... }:
let
  cfg = config.suites.development;
in
{
  options.suites.development.enable = lib.mkEnableOption "development tooling (vscode, docker, k8s, ...)";

  config = lib.mkIf cfg.enable {
    apps.vscode.enable = true;
    apps.zed.enable = true;
    apps.android.enable = true;
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
          claude-code
          # Claude Code shells out to node/npx for MCP servers and JS tooling,
          # and the package itself doesn't pull a runtime in.
          nodejs
        ];
      };
  };
}
