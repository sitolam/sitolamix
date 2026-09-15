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

          # DMS's matugen renders colors/dms.lua on every wallpaper change and
          # the file hot-reloads itself. Before DMS has run once the file does
          # not exist, so a bare `colorscheme dms` would error on every start;
          # pcall keeps nvim quiet until it appears.
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
