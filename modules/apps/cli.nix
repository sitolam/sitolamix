{ config, lib, ... }:
let
  cfg = config.apps.cli;
in
{
  options.apps.cli.enable = lib.mkEnableOption "core CLI tools (bat, eza, fzf, zoxide, btop, atuin, mise, ...)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        programs.bat.enable = true;
        programs.eza = {
          enable = true;
          icons = "auto";
          git = true;
        };
        programs.fzf = {
          enable = true;
          enableFishIntegration = true;
          # atuin owns Ctrl-R (rich history search); leave fzf's other widgets intact
          historyWidget.command = "";
        };
        programs.zoxide = {
          enable = true;
          enableFishIntegration = true;
        };
        programs.btop.enable = true;
        programs.atuin = {
          enable = true;
          enableFishIntegration = true;
          flags = [ "--disable-up-arrow" ];
        };
        programs.mise = {
          enable = true;
          enableFishIntegration = true;
        };

        home.packages = with pkgs; [
          dust
          ripgrep
          fd
          jq
          yq-go
          htop
          tree
          unzip
          zip
          wget
          curl
        ];
      };
  };
}
