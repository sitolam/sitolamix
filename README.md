# sitolamix

Personal NixOS dendritic flake. One theme, one host, one command to rebuild.

## Stack

- **Compositor**: [niri](https://github.com/YaLTeR/niri) (scrollable Wayland)
- **Bar / shell**: [noctalia](https://github.com/noctalia-dev/noctalia-shell)
- **Terminal**: [ghostty](https://ghostty.org/)
- **Shell**: fish + starship
- **Theming**: [stylix](https://github.com/nix-community/stylix) — fixed `catppuccin-mocha` base16 scheme; every themable app follows.
- **Boot**: GRUB EFI + [catppuccin-grub](https://github.com/catppuccin/grub) theme
- **Kernel**: cachyos-bore (via [xddxdd/nix-cachyos-kernel](https://github.com/xddxdd/nix-cachyos-kernel))
- **Filesystem**: ext4 root, `NIXROOT` + `NIXBOOT` labels (btrfs subvols on next reinstall — see `modules/hosts/hardware/gamingpc.nix`).

## Hosts

| Host | Machine |
|---|---|
| `gamingpc` | AMD CPU + NVIDIA GPU workstation, DP-3 primary + HDMI-A-1 secondary. |

## Structure

Dendritic — `flake-parts` + [`import-tree`](https://github.com/vic/import-tree). Every file registers itself into `flake.modules.nixos.<name>` or `flake.modules.homeManager.shared`. Hosts pick modules by name (no `options.suites.*` enable schema).

Home-manager runs as a NixOS module. Any file can mix HM + NixOS via `home.extraOptions` (see `modules/hm-integration.nix`).

## Rebuild

```sh
just rebuild        # nh os switch .
just update         # nix flake update + rebuild
just theme          # single-theme repo, no switcher
```

Fish wraps `just` so it works from any cwd (see `modules/home/shared/programs/fish.nix`).

## Attribution

Structural pattern adapted from **[lukasz-sz96/nixos-config](https://github.com/lukasz-sz96/nixos-config)** — dendritic layout, flake-parts + import-tree, noctalia integration.

HM + NixOS same-file mechanism (`home.extraOptions` + `mkAliasDefinitions`) adapted from a previous personal repo `quickhyprnix`.
