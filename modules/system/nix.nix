{ inputs, ... }:
{
  # Unfree in the NixOS + home-manager closures (HM shares this via useGlobalPkgs).
  nixpkgs.config.allowUnfree = true;

  # Unfree in ad-hoc CLI usage too (nix-shell -p, nix-build, --impure flake
  # commands) — without this those invocations abort on the unfree gate.
  environment.sessionVariables.NIXPKGS_ALLOW_UNFREE = "1";
  home.extraOptions.home.file.".config/nixpkgs/config.nix".text = ''
    { allowUnfree = true; }
  '';

  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Otherwise flake.nix's nixConfig substituters get ignored with a
      # warning every rebuild; safe since they're already in the trusted lists below.
      accept-flake-config = true;

      trusted-users = [
        "root"
        "otis"
      ];

      # garnix.io was dropped: its 502s interrupt the nix daemon mid-rebuild,
      # and it only served zen-browser, which is cheap to build locally.
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://niri.cachix.org"
      ];

      trusted-substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://niri.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      ];

      auto-optimise-store = true; # hardlink-dedupe identical store paths (saves disk)
    };

    gc.automatic = false; # redundant with nh clean below (generation-aware)
  };

  # nh's clean timer supersedes nix.gc: keeps a minimum number of generations
  # regardless of age, so a rebuild spree can't zero out rollback targets.
  programs.nh = {
    enable = true; # installs nh (replaces the systemPackages entry)
    flake = "/home/otis/sitolamix"; # lets `nh os switch` run with no path arg

    clean = {
      enable = true;
      dates = "daily"; # this box is tight on storage
      extraArgs = "--keep 3 --keep-since 4d"; # tighten to reclaim more
    };
  };
}
