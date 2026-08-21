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
          ncdu # interactive TUI disk-usage browser (complements dust)
          micro # simple modeless terminal editor
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

          # terminal eye candy — no config, so they sit here with the rest
          lavat # ASCII lava lamp: -g truecolor gradient, -G gravity, -p party
          pipes-rs # the pipes screensaver, rust rewrite of pipes.sh
          cmatrix # `cmatrix -ab` — the green rain
          cbonsai # `cbonsai -l` — grows a bonsai, live
          asciiquarium # fish tank
          peaclock # clock/timer/stopwatch, styled from a config file
          tty-clock # `tty-clock -c -C 5` — big centred digits
        ];
      };
  };
}
