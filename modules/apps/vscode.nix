{ config, lib, ... }:
let
  cfg = config.apps.vscode;
in
{
  options.apps.vscode.enable = lib.mkEnableOption "Visual Studio Code";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        programs.vscode = {
          enable = true;
          package = pkgs.vscode;
        };
      };

    # ensure electron apps run natively on wayland
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
