{
  config,
  lib,
  inputs,
  ...
}:
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

          plugins = [
            (pkgs.vimUtils.buildVimPlugin {
              pname = "base46-dms";
              version = inputs.base46-dms.shortRev or "unstable";
              src = inputs.base46-dms;
              # plugin runtime is loaded lazily by the colorscheme; nothing to require-check.
              doCheck = false;
            })
          ];

          # pcall: colors/dms.lua is rendered by DMS's matugen on the first
          # wallpaper change and doesn't exist before that.
          initLua = ''
            pcall(vim.cmd.colorscheme, "dms")
          '';
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
