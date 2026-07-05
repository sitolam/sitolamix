# sitolamix

Personal NixOS flake. Enable-options + suites, home-manager folded into each feature file.

## Stack

- **Compositor**: [niri](https://github.com/YaLTeR/niri) (scrollable Wayland)
- **Bar / shell**: [noctalia](https://github.com/noctalia-dev/noctalia-shell)
- **Terminal**: [ghostty](https://ghostty.org/)
- **Shell**: fish + starship
- **Theming**: [stylix](https://github.com/nix-community/stylix) — fixed `catppuccin-mocha` base16 scheme; every themable app follows.
- **Boot**: GRUB EFI + [catppuccin-grub](https://github.com/catppuccin/grub) theme
- **Kernel**: linux-zen (cachyos-bore pending, see `modules/system/boot/kernel.nix`).
- **Filesystem**: ext4 root, `NIXROOT` + `NIXBOOT` labels (btrfs subvols on next reinstall — see `hosts/gamingpc/hardware.nix`).

## Hosts

| Host | Machine |
|---|---|
| `gamingpc` | AMD CPU + NVIDIA GPU workstation, DP-3 primary + HDMI-A-1 secondary. |

## Structure

`flake-parts` + [`import-tree`](https://github.com/vic/import-tree). Every `.nix` file under `modules/` is auto-imported into every host — **no manual imports list**. Hosts under `hosts/<name>/` are **auto-discovered** (adding a machine = adding a folder).

```
flake.nix              flake description + inputs
flake/                 flake-parts modules (systems builder, devshell, formatter)
hosts/<name>/          per-host: default.nix (suite toggles) + hardware.nix
modules/
  hm.nix               home-manager bridge — the `home.extraOptions` mechanism
  system/              always-on baseline (base, nix, locale, users, boot, ...)
  hardware/            audio/bluetooth/graphics baseline; nvidia gated
  desktop/             niri, noctalia, stylix, kanata (gated)
  services/            docker (gated)
  apps/                one file per app, each `apps.<name>.enable`
  suites/              groups that flip a batch of enables (core, desktop, dev, ...)
```

### Enable-options + suites

Each feature declares `options.<ns>.<name>.enable` and gates its config with
`lib.mkIf`. Suites toggle groups of them; hosts just flip suites:

```nix
# hosts/gamingpc/default.nix
suites = {
  core.enable = true;        # shell + CLI programs
  desktop.enable = true;     # niri + noctalia + stylix + kanata
  development.enable = true;  # vscode, docker, k8s tooling
  media.enable = true;
  gaming.enable = true;
  # ...
};
hardware.nvidia.enable = true;
```

### home-manager in one file

Home-manager runs as a NixOS module (`modules/hm.nix`). Any file mixes system +
HM config together by writing `home.extraOptions` — an attrset, or a function
`{ config, ... }: { ... }` when it needs HM's own `config` (e.g. stylix colors).
`home.extraOptions` is a `deferredModule`, so every file's contribution merges
into `home-manager.users.otis`. There is no separate `home/` tree.

```nix
{ config, lib, ... }:
{
  options.apps.ghostty.enable = lib.mkEnableOption "ghostty terminal";
  config = lib.mkIf config.apps.ghostty.enable {
    home.extraOptions.programs.ghostty.enable = true;   # home-manager, same file
  };
}
```

## Rebuild

```sh
just rebuild        # nh os switch .
just update         # nix flake update + rebuild
just check          # nix flake check --no-build
just drybuild       # dry-run build of the current host
```

Fish also wraps `just` so it works from any cwd (see `modules/apps/fish.nix`).

## Attribution

HM + NixOS same-file mechanism (`home.extraOptions` + deferred module) and the
enable-options/suites layout adapted from a previous personal repo `quickhyprnix`.
