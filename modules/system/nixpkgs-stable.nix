{ config, inputs, ... }:
{
  # `pkgs.stable.<name>` (nixos-26.05): escape hatch for a package that is
  # broken on unstable. Comment why at the use site and drop it once fixed;
  # each one pulls a second closure (glibc, Qt, ...) into the store.
  nixpkgs.overlays = [
    (_final: prev: {
      stable = import inputs.nixpkgs-stable {
        inherit (prev.stdenv.hostPlatform) system;
        # Not `prev.config`: stable fails on its unstable-only `rewriteURL`.
        config = config.nixpkgs.config;
      };
    })
  ];
}
