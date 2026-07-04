_:
{
  flake.modules.homeManager.shared = {
    programs.ghostty = {
      enable = true;
      settings = {
        font-family = "MesloLGS Nerd Font Mono";
        font-size = 13;
        window-padding-x = 14;
        window-padding-y = 14;
        confirm-close-surface = false;
      };
    };
  };
}
