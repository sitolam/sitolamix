{ inputs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      trusted-users = [
        "root"
        "otis"
      ];

      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://niri.cachix.org"
        "https://noctalia.cachix.org"
        "https://hyprland.cachix.org"
        "https://cache.garnix.io"
        "https://attic.xuyh0120.win/lantian"
      ];

      trusted-substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://niri.cachix.org"
        "https://noctalia.cachix.org"
        "https://hyprland.cachix.org"
        "https://cache.garnix.io"
        "https://attic.xuyh0120.win/lantian"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      ];

      auto-optimise-store = true; # hardlink-dedupe identical store paths (saves disk)
    };

    # Garbage collection is handled by `nh clean` below (programs.nh.clean), which
    # is generation-aware. Running nix.gc *and* nh clean is redundant, so the
    # built-in timer stays off.
    gc.automatic = false;
  };

  # nh = the nice `nix os switch` wrapper (already used by the `rebuild`/`update`
  # fish aliases). Its clean timer supersedes nix.gc: it keeps a minimum number
  # of generations regardless of age, so a rebuild spree can't leave you with
  # zero rollback targets, while still reclaiming disk aggressively.
  programs.nh = {
    enable = true; # installs nh (replaces the systemPackages entry)
    flake = "/home/otis/sitolamix"; # lets `nh os switch` run with no path arg

    clean = {
      enable = true;
      dates = "daily"; # run often — this box is tight on storage
      # keep the 3 newest generations no matter what, plus anything from the last
      # 4 days. Tighten `--keep`/`--keep-since` further to reclaim more.
      extraArgs = "--keep 3 --keep-since 4d";
    };
  };
}
