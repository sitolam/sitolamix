{
  perSystem =
    { pkgs, ... }:
    {
      # Bare nixfmt as a flake formatter is deprecated; nixfmt-tree is the
      # treefmt wrapper upstream points at instead.
      formatter = pkgs.nixfmt-tree;
    };
}
