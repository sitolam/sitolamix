{ config, lib, ... }:
let
  cfg = config.apps.sage;
in
{
  options.apps.sage.enable = lib.mkEnableOption "SageMath, with a Jupyter kernel for VS Code notebooks";

  config = lib.mkIf cfg.enable {
    # The nixpkgs VS Code Jupyter extension's zeromq has no build for its
    # Electron, so it starts kernels through `python -m jupyter` on the system
    # interpreter (apps.python). Drop once its log stops showing
    # "No native build was found" for zeromq.
    apps.python.extraPackages = ps: [ ps.notebook ];

    home.extraOptions =
      { pkgs, ... }:
      let
        inherit (pkgs.sage) kernelspec;
      in
      {
        home.packages = [ pkgs.sage ];

        # Registers Sage as a Jupyter kernel so VS Code's notebook kernel
        # picker (ms-toolsai.jupyter, apps.vscode) can run .ipynb in Sage.
        xdg.dataFile = {
          "jupyter/kernels/sagemath/kernel.json".text = builtins.toJSON {
            inherit (kernelspec) argv language;
            display_name = kernelspec.displayName;
          };
          "jupyter/kernels/sagemath/logo-32x32.png".source = kernelspec.logo32;
          "jupyter/kernels/sagemath/logo-64x64.png".source = kernelspec.logo64;
        };
      };
  };
}
