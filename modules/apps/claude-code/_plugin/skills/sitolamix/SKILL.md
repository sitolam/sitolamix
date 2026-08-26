---
name: sitolamix
description: Use when adding, editing, reviewing or removing anything in the sitolamix NixOS flake — a new app/service/host module, an option rename, a suite change, a secret, a theme value — or when a change to it fails to evaluate, fails nix flake check, or gets clobbered on rebuild.
---

# sitolamix

Personal NixOS flake: niri + DankMaterialShell + stylix, one file per feature,
nothing imported by hand. Repo root is `~/sitolamix`.

## The one rule

**A feature is one file.** It declares its own `enable` option, gates its system
config with `lib.mkIf`, *and* folds in its home-manager config. There is no
parallel `home/` tree. Never split a feature across a system file and a home
file.

```nix
{ config, lib, ... }:
let
  cfg = config.apps.ghostty;
in
{
  options.apps.ghostty.enable = lib.mkEnableOption "ghostty terminal";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ ... ];           # system half
    home.extraOptions.programs.ghostty.enable = true;  # home-manager half
  };
}
```

`home.extraOptions` is a `deferredModule` (see `modules/hm.nix`). Use a plain
attrset, or `{ pkgs, lib, ... }: { ... }` when you need home-manager's own args.
Every module's contribution merges into `home-manager.users.otis`.

## Where a file goes

`modules/` is auto-imported by import-tree — **never add an imports list**.
Hosts under `hosts/<name>/` are auto-discovered.

| Namespace | Directory |
|---|---|
| `apps.<name>` | `modules/apps/` |
| `desktop.<name>` | `modules/desktop/` |
| `services.<name>` | `modules/services/` |
| `hardware.<name>` | `modules/hardware/` |
| `theming.<name>` | `modules/theming/` |
| `suites.<name>` | `modules/suites/` |

**The namespace and the directory must agree.** A module declaring `theming.*`
belongs in `modules/theming/`, not wherever it started life.

Two structural conventions:

- **Sidecar files mean a directory.** A lone module is `foo.nix`; a module with
  a script, a config file or assets is `foo/default.nix` plus those files.
- **Non-module data goes in `_lib/`.** import-tree's filter is
  `andNot (hasInfix "/_") (hasSuffix ".nix")`, so anything under a `_`-prefixed
  path is skipped and won't be mistaken for a NixOS module. App-specific data
  lives beside its module (`modules/apps/anki/_lib/`); cross-cutting data read
  by several modules lives at the repo root (`themes/`).

## Wiring it up

Hosts flip suites; suites flip modules. A host should almost never enable a
module directly — if it does, that is a host-specific decision and needs a
comment saying why.

```nix
# modules/suites/<suite>.nix
apps.<name>.enable = true;
```

Group repeated prefixes into one attribute set (`apps = { a.enable = …; b.enable = …; }`);
statix enforces this.

## Rules that bite

| Situation | Do this |
|---|---|
| Name collides with a nixpkgs option (`services.printing`) | Suffix yours (`services.printing-cups`) **and comment why** at the top of the file |
| Package broken on unstable | `pkgs.stable.<name>` — see `modules/system/nixpkgs-stable.nix`. Comment what broke and when to drop it |
| Any colour, font or wallpaper | Read it from `themes/<name>.nix`. Never hardcode a hex value in a module |
| A secret | sops. Declare `sops.secrets.<name>`, reference `config.sops.secrets.<name>.path`, **never the value**. Edit with `just secret secrets/<file>.yaml` |
| New flake input | Add to `flake.nix` with a comment saying what it is and why it isn't in nixpkgs |
| Vendoring third-party code | Keep its licence files. Add a row to `modules/apps/anki/_lib/vendored/README.md` if it is an Anki add-on |

**Files this repo owns, that apps also write:** Claude Code's plugin manifests,
DMS's `outputs.kdl`, Anki's `meta.json`. Changing them in the app's own UI will
not stick, or will be overwritten. Change the Nix, not the app.

## Comments are the deliverable

The long comments in these files are the documentation — the README says so
explicitly. When you write a workaround, the comment must record **why it
exists and when it can be removed**, not what the code does. A commit that adds
a workaround with no such comment is incomplete.

## Verify before claiming done

```sh
just fmt        # nixfmt via treefmt
just check      # nix flake check --no-build (evaluates BOTH hosts)
just drybuild   # dry-run build of this host
just diff       # nvd diff /run/current-system result  — after `just build`
```

Both linters must stay clean:

```sh
nix shell nixpkgs#statix nixpkgs#deadnix --command sh -c 'statix check .; deadnix modules/ hosts/ themes/ flake/ flake.nix'
```

`just check` evaluating is **not** proof a refactor is behaviour-preserving.
For anything that claims to be a pure refactor, run `just build` then
`just diff` and confirm the closure delta is empty or is exactly what you
intended.

## Common mistakes

- **Adding an `imports = [ ... ]` for a new module.** import-tree already found
  it. Only `hosts/<name>/default.nix` imports its own `hardware.nix`.
- **Writing a config file for a package you never installed.** Check the module
  actually adds the package — `apps.fastfetch` shipped a 90-line config for a
  binary that was never on `PATH`.
- **Putting app data at the repo root** to dodge import-tree. Use `_lib/`.
- **Editing `flake.lock` by hand.** Use `nix flake update <input>`.
- **Leaving a module enabled by nothing.** If no suite and no host turns it on,
  it is dead code — delete it, and its flake input and cachix entry with it.
