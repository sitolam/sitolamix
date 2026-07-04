_:
{
  flake.modules.homeManager.shared = {
    programs.starship = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
