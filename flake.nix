{
  description = "sitolamix — enable-options NixOS: niri + noctalia + stylix (catppuccin-mocha)";

  nixConfig = {
    # garnix / hyprland / lantian were dropped — see modules/system/nix.nix.
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://niri.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Escape hatch, not a second base: the current stable release, surfaced as
    # `pkgs.stable.<name>` by modules/system/nixpkgs-stable.nix. Deliberately
    # does NOT follow nixpkgs — following it would defeat the entire point.
    # Nothing uses it by default; see that module for when to reach for it.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia.url = "github:noctalia-dev/noctalia-shell";

    # niri scratchpad (Rust). packages.default = the `niri-scratchpad` binary.
    niri-scratchpad = {
      url = "github:argosnothing/niri-scratchpad-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # heyoeyo/niri_tweaks — stdlib-only python IPC scripts (no flake); we run
    # niri_tile_to_n.py at startup. flake=false => the repo is a plain src path.
    niri-tweaks = {
      url = "github:heyoeyo/niri_tweaks";
      flake = false;
    };

    # DankMaterialShell (Quickshell + Go). Tried on this branch as an
    # alternative to noctalia; drives blur via niri's ext-background-effect.
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AvengeMedia/dank-greeter — the greetd login screen that matches the DMS
    # lock screen. The flake's own nixpkgs only feeds its `packages` output; the
    # NixOS module builds dms-greeter from the importing config's pkgs.
    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium.url = "github:FKouhai/helium2nix";

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # sitolam/dms-mouthguard — DMS plugin, not in dms-plugin-registry, so it is
    # pinned as its own input. Tracks the repo's default branch; local edits
    # over in the working checkout are picked up only once they are pushed and
    # `nix flake update dms-mouthguard` is run.
    dms-mouthguard = {
      url = "github:sitolam/dms-mouthguard";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ (inputs.import-tree ./flake) ];
    };
}
