# sitolamix — house rules

Personal NixOS flake: niri + DankMaterialShell + stylix. Read this before
changing anything here.

## The one rule

**A feature is one file.** It declares its own `enable` option, gates its system
config with `lib.mkIf`, *and* folds in its home-manager config. There is no
parallel `home/` tree — never split a feature across a system file and a home
file.

```nix
{ config, lib, ... }:
let
  cfg = config.apps.ghostty;
in
{
  options.apps.ghostty.enable = lib.mkEnableOption "ghostty terminal";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ ... ];              # system half
    home.extraOptions.programs.ghostty.enable = true;  # home-manager half
  };
}
```

`home.extraOptions` is a `deferredModule` (`modules/hm.nix`). Use a plain
attrset, or `{ pkgs, lib, ... }: { ... }` when you need home-manager's own args.
Every module's contribution merges into `home-manager.users.otis`.

## Where a file goes

`modules/` is auto-imported by import-tree — **never add an `imports` list.**
Only `hosts/<name>/default.nix` imports anything (its own `hardware.nix`).
Hosts are auto-discovered from `hosts/`.

| Namespace | Directory |
|---|---|
| `apps.<name>` | `modules/apps/` |
| `desktop.<name>` | `modules/desktop/` |
| `services.<name>` | `modules/services/` |
| `hardware.<name>` | `modules/hardware/` |
| `theming.<name>` | `modules/theming/` |
| `suites.<name>` | `modules/suites/` |

**The namespace and the directory must agree.**

- **Sidecar files mean a directory.** A lone module is `foo.nix`; a module with
  a script, config file or assets is `foo/default.nix` plus those files. When
  the sidecars go away, it goes back to being a flat file.
- **Non-module data goes in a `_`-prefixed directory.** import-tree's filter is
  `andNot (hasInfix "/_") (hasSuffix ".nix")`, so anything under `/_…` is
  skipped and can't be mistaken for a NixOS module — that is what
  `modules/apps/anki/_lib/` is. Cross-cutting data read by several modules
  (`themes/`) lives at the repo root instead.

Hosts flip suites; suites flip modules. A host enabling a module directly is a
host-specific decision and needs a comment saying why.

Group repeated attribute prefixes into one set (`apps = { a.enable = …; }`) —
statix enforces this.

## Rules that bite

| Situation | Do this |
|---|---|
| Name collides with a nixpkgs option (`services.printing`) | Suffix yours (`services.printing-cups`) **and comment why** at the top of the file |
| Package broken on unstable | `pkgs.stable.<name>`, see `modules/system/nixpkgs-stable.nix`. Comment what broke and when to drop it |
| Any colour, font or wallpaper | Read it from `themes/<name>.nix`. Never hardcode a hex value in a module |
| A secret | sops. Declare `sops.secrets.<name>`, reference `config.sops.secrets.<name>.path`, **never the value**. Edit with `just secret secrets/<file>.yaml` |
| New flake input | Comment what it is and why it isn't in nixpkgs |
| Vendoring third-party code | Keep its licence files. Anki add-ons also need a row in `modules/apps/anki/_lib/vendored/README.md` — the repo is GPL-3.0 but vendored code is not |

**Files this repo owns that applications also write:** Claude Code's plugin
manifests, DMS's `outputs.kdl`, Anki's `meta.json`, VS Code's `keybindings.json`
(and its `settings.json`, which stylix owns). Changing these in the app's own UI
will not stick, or will be overwritten on the next rebuild. Change the Nix, not
the app.

VS Code's *extensions* are the exception: `mutableExtensionsDir = true` keeps
`~/.vscode/extensions` writable so Claude Code's CLI and stylix can drop their
own extensions in. Anything you install from the marketplace by hand therefore
survives a rebuild — and is invisible to this repo. Add it to
`modules/apps/vscode.nix` or it is not part of the config.

## Comments are the deliverable

The long comments in these files are the documentation — the README says so
explicitly. A workaround's comment must record **why it exists and when it can
be removed**, not what the code does. A commit adding a workaround without one
is incomplete.

## Verify before claiming done

```sh
just fmt        # nixfmt via treefmt
just check      # nix flake check --no-build — evaluates BOTH hosts
just drybuild   # dry-run build of this host
just build && just diff   # nvd diff /run/current-system result
```

Both linters must stay clean:

```sh
nix shell nixpkgs#statix nixpkgs#deadnix --command sh -c \
  'statix check .; deadnix modules/ hosts/ themes/ flake/ flake.nix'
```

**`just check` passing is not proof a refactor preserved behaviour.** For
anything claiming to be a pure refactor, run `just build` then `just diff` and
confirm the closure delta is empty or is exactly what you intended.

## Common mistakes

- Adding an `imports = [ ... ]` for a new module. import-tree already found it.
- Writing a config file for a package the module never installs — `apps.fastfetch`
  shipped a 90-line config for a binary that was never on `PATH`.
- Putting app data at the repo root to dodge import-tree. Use `_lib/`.
- Editing `flake.lock` by hand. Use `nix flake update <input>`.
- Leaving a module that nothing enables. If no suite and no host turns it on it
  is dead code — delete it, along with its flake input and cachix entry.
