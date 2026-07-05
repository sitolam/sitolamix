{ inputs, lib, ... }:
let
  hostsDir = ../hosts;

  hostNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir hostsDir)
  );

  mkHost =
    name:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        # every file under ./modules is auto-imported — no manual list to keep.
        (inputs.import-tree ../modules)
        # host-specific: enables suites + host toggles, imports its own hardware.nix.
        (hostsDir + "/${name}")
      ];
    };
in
{
  flake.nixosConfigurations = lib.genAttrs hostNames mkHost;
}
