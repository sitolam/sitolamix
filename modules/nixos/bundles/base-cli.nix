_:
{
  flake.modules.nixos.base-cli =
    { pkgs, ... }:
    {
      home.extraOptions = {
        programs.bat.enable = true;
        programs.eza = {
          enable = true;
          icons = "auto";
          git = true;
        };
        programs.fzf = {
          enable = true;
          enableFishIntegration = true;
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
