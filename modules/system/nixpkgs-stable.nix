{ config, inputs, ... }:
{
  # `pkgs.stable.<name>` — the current stable release (nixos-26.05, see the
  # nixpkgs-stable input) alongside the unstable base.
  #
  # This is an escape hatch for single packages, not a second package set to
  # spread across the config. The desktop stack is the reason: niri, DMS,
  # quickshell, stylix and home-manager all follow the unstable `nixpkgs`, and
  # they are the parts that hurt when they break — so unstable stays the base
  # and stable is reached for one package at a time.
  #
  # Use it when an app breaks on unstable and you would otherwise roll the whole
  # lock back. On 2026-08-05 a full `nix flake update` was blocked exactly like
  # this: anki 25.09.4 failed its offline uv resolve ("iniconfig was not found
  # in the cache"). The fix for that shape of problem is one line:
  #
  #   home.packages = [ pkgs.stable.anki ];   # unstable's anki is broken, see <link>
  #
  # Always leave a comment saying why, and drop back to the unstable package
  # once upstream is fixed — every package taken from here drags a second
  # closure (its own glibc, Qt, …) into the store, and this box is tight on
  # disk. Nothing uses it right now, so it currently costs only the lock entry.
  nixpkgs.overlays = [
    (_final: prev: {
      stable = import inputs.nixpkgs-stable {
        inherit (prev.stdenv.hostPlatform) system;
        # The *declared* nixpkgs config (allowUnfree, see ./nix.nix), so a stable
        # package does not trip the unfree gate its unstable twin passes.
        # Deliberately not `prev.config`: that is the fully evaluated config,
        # carrying unstable-only internals that stable types differently — it
        # fails on `rewriteURL` ("definition is not of type function that
        # evaluates to (null or string)").
        config = config.nixpkgs.config;
      };
    })
  ];
}
