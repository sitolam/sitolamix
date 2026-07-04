_:
{
  flake.modules.homeManager.shared =
    { pkgs, ... }:
    {
      programs.neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
      };

      home.packages = with pkgs; [
        fd
        gcc
        gnumake
        ripgrep
        tree-sitter
      ];
    };
}
