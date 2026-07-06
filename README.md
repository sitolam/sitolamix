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

## Secrets (sops)

Secrets are encrypted with [sops-nix](https://github.com/Mic92/sops-nix) using
**age**, committed to git as ciphertext, and decrypted at activation to
`/run/secrets/<name>` (tmpfs — never in the nix store or git in plaintext). The
config references the decrypted *path*, never the value.

- `modules/system/sops.nix` — imports the sops module, sets the sops file and
  the decryption key (the machine's SSH host key), and declares each secret.
- `.sops.yaml` — the age recipients allowed to decrypt (creation rules).
- `secrets/*.yaml` — the encrypted secret files.

The decryption key is `/etc/ssh/ssh_host_ed25519_key`, converted to age. Get the
matching **public** key (the recipient for `.sops.yaml`) with:

```sh
nix run nixpkgs#ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

Add / edit a secret (opens `$EDITOR` with the decrypted content, re-encrypts on
save):

```sh
nix run nixpkgs#sops -- secrets/ha.yaml
```

Then declare it and reference the runtime path:

```nix
# modules/system/sops.nix
sops.secrets.hass_token = { owner = "otis"; mode = "0400"; };

# consumer, e.g. modules/desktop/dms.nix
config.sops.secrets.hass_token.path   # => /run/secrets/hass_token
```

Adding another machine: add its age key to `.sops.yaml` and run
`sops updatekeys secrets/ha.yaml`. To rotate a secret, edit it as above and
replace the value — the old ciphertext is overwritten.

## Attribution

HM + NixOS same-file mechanism (`home.extraOptions` + deferred module) and the
enable-options/suites layout adapted from a previous personal repo `quickhyprnix`.
