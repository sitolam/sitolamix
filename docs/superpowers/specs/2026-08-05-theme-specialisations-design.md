# Theme specialisations: instant theme switching, wallpaper decoupled

**Date:** 2026-08-05
**Status:** approved, ready for implementation

## Problem

Theming has two complaints, and they are separate problems wearing one coat.

**Colours are stuck.** `themes/` holds exactly one theme, and changing it means a
rebuild. Stylix is not to blame for bad colours here — `stylix.nix:34` pins
`base16Scheme` to `catppuccin-mocha.yaml`, so nothing is being extracted from the
wallpaper at all. The wish is a *set* of good schemes, switchable in seconds.

**The wallpaper cannot be changed.** `~/.local/state/DankMaterialShell/session.json`
is a read-only store symlink, so DMS physically cannot write a new
`wallpaperPath`. Today the wallpaper is a property of the theme
(`themes/<name>.nix` → `stylix.image` → stylix's DMS target → `session.json`).

Wallpaper-derived colours were considered and rejected: base16 wants eight
distinct accent hues, and every wallpaper extractor (stylix's own, or matugen's
Material You tones) produces variations on one or two hues instead. That
mismatch *is* the "colours aren't great" complaint. Curated schemes sidestep it.

## Solution

Themes stay curated data. Each becomes a **NixOS specialisation**, so every
theme is prebuilt and switching is an activation of an existing closure —
seconds, no rebuild, no eval. The wallpaper stops being a theme property and
becomes runtime state owned by DMS.

### Theme registry

`themes/default.nix` grows a shared `dms` mapping and a `mkTheme` helper. The
existing mapping is **slot names, not colours** (`primary = "base0E"`), so it is
theme-independent and every scheme can share it. A theme file becomes:

```nix
{
  themeName = "nord";
  polarity = "dark";
}
```

Six themes, chosen for distinct personality rather than six shades of one idea:
`catppuccin-mocha` (default), `nord`, `gruvbox-dark-hard`, `tokyo-night-storm`,
`rose-pine`, `everforest-dark-medium`. All ship in `pkgs.base16-schemes`
(tinted-theming's collection, 303 schemes) — the collection stylix already
vendors, and there is no better one to go find.

### Specialisations

Generated from the registry, so adding a theme stays a one-file change:

```nix
specialisation = lib.mapAttrs (name: _: {
  configuration.theming.stylix.theme = lib.mkForce name;
}) (removeAttrs themes.themes [ cfg.theme ]);
```

The active theme is excluded — it is the base configuration already, and a
specialisation of it would be a duplicate closure for nothing.

### Switching

`theme <name>`, plus one desktop entry per theme ("Theme: Nord") so `Mod+Space`
→ "theme" lists them. No new dependency; it reuses the launcher already in use.

The switch runs:

```
/nix/var/nix/profiles/system/specialisation/<name>/bin/switch-to-configuration switch
```

**Not** `/run/current-system/specialisation/...`. Specialisations are not
recursive: once you have switched into one, `/run/current-system` *is* that
specialisation and no longer lists its siblings, so a second switch would fail.
The system profile always points at the parent generation, which has all of
them. Returning to the default theme is the same path without the
`specialisation/<name>` segment.

`switch-to-configuration` needs root, so a sudoers rule grants NOPASSWD for
exactly those two command paths. In sudoers a `*` does not match `/`, so the
wildcard is confined to one path component, and
`/nix/var/nix/profiles/system` is a root-owned symlink the user cannot repoint.
This grants nothing new in practice: `trusted-users = otis` in
`modules/system/nix.nix` is already root-equivalent.

### Wallpaper decoupling

Three changes, all forced by one line in the DMS home module
(`xdg.stateFile."DankMaterialShell/session.json" = lib.mkIf (cfg.session != {})`):

1. `stylix.image = null` — stylix stops owning a wallpaper. The option is
   `null or path`, so this is supported, and nothing else in this config draws
   the wallpaper: DMS does.
2. `programs.dank-material-shell.session` must end up `{}`, which means the
   `weatherLocation` / `weatherCoordinates` / `nightMode*` keys currently in
   `modules/desktop/dms/default.nix` cannot stay declarative. Same file, no
   partial ownership.
3. Those keys are instead **seeded once** by a home-manager activation script
   that writes `session.json` only when it is absent or is still a store
   symlink from a previous generation. Fresh machines stay reproducible;
   afterwards the file is mutable and DMS owns it.

`themes/*.nix` keeps no `wallpaper` attribute. A single repo-level default
(`assets/wallpaper.jpg`) is what the seeder writes as the initial wallpaper.

## Known limitations

- **Theme choice does not survive a reboot.** A specialisation activated with
  `switch-to-configuration` does not change the boot default, so a reboot
  returns to the base theme. The specialisations do appear as GRUB entries.
  Persisting the choice would need a boot-time service re-applying the last
  selection — deliberately out of scope until the switching itself proves out.
- **Already-open terminals keep their old colours.** ghostty reads its config at
  startup. DMS and GTK apps repaint promptly; terminals need a relaunch.
- **Disk.** Six themes means five extra system closures. They share nearly
  everything; the delta is regenerated config files, GTK theme and icon caches.
  This box is tight on storage, so the set stays small deliberately.

## Testing

1. `nix build` produces `specialisation/{nord,gruvbox-dark-hard,…}` under the
   toplevel.
2. `theme nord` completes in seconds and DMS repaints.
3. `theme catppuccin-mocha` (the base) returns via the profile path, proving the
   non-recursive-specialisation trap is handled.
4. `session.json` is a real file, not a symlink; changing the wallpaper in DMS
   sticks, and survives a theme switch.
5. A theme switch does not revert the wallpaper.
