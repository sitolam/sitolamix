{ config, lib, ... }:
let
  cfg = config.suites.core;
in
{
  options.suites.core.enable = lib.mkEnableOption "core shell + CLI programs every host wants";

  config = lib.mkIf cfg.enable {
    apps = {
      fish.enable = true;
      git.enable = true;
      ghostty.enable = true;
      starship.enable = true;
      tmux.enable = true;
      direnv.enable = true;
      neovim.enable = true;
      yazi.enable = true;
      fastfetch.enable = true;
      nitch.enable = true;
      toys.enable = true;
      cli.enable = true;
      nautilus.enable = true;
      gparted.enable = true;
    };

    # default desktop utilities every host wants (alongside nautilus/gparted).
    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.mission-center # GUI system monitor (GNOME-style task manager)
        ];
      };
  };
}
