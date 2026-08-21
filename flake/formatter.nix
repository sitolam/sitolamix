{
  perSystem =
    { pkgs, ... }:
    {
      # `nixfmt-rfc-style` is a deprecated alias for `nixfmt`, and bare `nixfmt`
      # as a flake formatter is deprecated too: `nix fmt` with no argument feeds
      # it stdin ("Bare invocation of nixfmt is deprecated"), `nix fmt .` warns
      # about passing a directory. nixfmt-tree is the treefmt wrapper upstream
      # points at, and it walks the tree itself.
      formatter = pkgs.nixfmt-tree;
    };
}
