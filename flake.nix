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

    # sitolam/dms-mouthguard — DMS plugin, still local-only (no remote yet), so
    # it is pinned to the working checkout rather than the registry. A path
    # input is the only way to reference it: pure evaluation rejects a bare
    # absolute path in a module. Two consequences while it stays local:
    #   * every other clone of this (public) repo fails to evaluate;
    #   * edits over there need `nix flake update dms-mouthguard` to be picked up.
    # Swap this for `github:sitolam/dms-mouthguard` once it is pushed.
    dms-mouthguard = {
      url = "git+file:///home/otis/Documents/dms-mouthguard?ref=feat/plugin-implementation";
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
