{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        name = "sitolamix";
        packages = with pkgs; [
          gh
          nh
          nvd
          just
          nixfmt
          deadnix
          statix
          nil
          nixd
          git
        ];
      };
    };
}
