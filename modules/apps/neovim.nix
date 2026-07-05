{ config, lib, ... }:
let
  cfg = config.apps.neovim;
in
{
  options.apps.neovim.enable = lib.mkEnableOption "neovim (default editor)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        programs.neovim = {
          enable = true;
          defaultEditor = true;
          viAlias = true;
          vimAlias = true;
          # no plugins use the ruby/python remote providers — adopt the new lean default
          withRuby = false;
          withPython3 = false;
        };

        home.packages = with pkgs; [
          fd
          gcc
          gnumake
          ripgrep
          tree-sitter
        ];
      };
  };
}
