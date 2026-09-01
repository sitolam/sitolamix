# Keybindings

Every bind in this config comes from one grammar. Learn the four modifiers
once and you can guess a bind you have never pressed.

| Modifier | Meaning |
| --- | --- |
| `Mod` | act on the focused thing, or open the thing named by the key |
| `Mod+Shift` | move the focused thing |
| `Mod+Ctrl` | act one scope up — the monitor, or the workspace itself |
| `Mod+Alt` | on a nav key: move **without following**. On a letter: run a tool |

Two rules keep it honest:

- **`Shift+X` and `Ctrl+X` are always variants of `Mod+X`.** If a key means
  "screenshot", every modifier on that key means some flavour of screenshot.
  Nothing hides an unrelated launcher behind a modifier.
- **Navigation is generated, not listed.** `bindings.nix` builds the nav
  planes from `mkBinds` / `mkNumberBinds` / `mkScrollBinds`, so arrows and
  `hjkl` cannot drift apart and a plane cannot be half-bound.

Where the grammar bends, it says so below. There are two places.

## Navigation

### Direction — `←↓↑→` and `hjkl`

Both key sets are always bound to the same action.

| | `h` / `←` | `j` / `↓` | `k` / `↑` | `l` / `→` |
| --- | --- | --- | --- | --- |
| `Mod` | focus column left | focus window down | focus window up | focus column right |
| `Mod+Shift` | move column left | move window down | move window up | move column right |
| `Mod+Ctrl` | focus monitor left | focus monitor down | focus monitor up | focus monitor right |
| `Mod+Ctrl+Shift` | column → monitor left | column → monitor down | column → monitor up | column → monitor right |
| `Mod+Alt` | swap window left | — | — | swap window right |

`Mod+Alt` has no "without following" meaning here — every target is already
on screen — so the horizontal half is spent on swapping windows in place.
Up/down stay unbound.

`h`/`l` cross columns, `j`/`k` move inside one. That is niri's model, not
vim's: a column is the unit of horizontal movement.

### Workspaces — `u` / `i` and `PgUp` / `PgDn`

Both key sets are always bound to the same action. `u` is up, `i` is down.

| | up | down |
| --- | --- | --- |
| `Mod` | focus workspace up | focus workspace down |
| `Mod+Shift` | move column to workspace up, **follow it** | move column to workspace down, **follow it** |
| `Mod+Alt` | move column to workspace up, **stay put** | move column to workspace down, **stay put** |
| `Mod+Ctrl` | move the workspace itself up | move the workspace itself down |

**Bend #1:** `Mod+Ctrl` reorders the workspace rather than reaching for the
monitor. On this axis plain `Mod` is already the scope-up — it moves between
workspaces — so the next scope up is the workspace as an object.

### Workspaces by number — `1`–`9` and `0`

`0` is workspace 10.

| | action |
| --- | --- |
| `Mod+<n>` | focus workspace *n* |
| `Mod+Shift+<n>` | move column to workspace *n*, follow it |
| `Mod+Alt+<n>` | move column to workspace *n*, stay put |
| `Mod+Ctrl+<n>` | move the current workspace to index *n* |

`workspace-auto-back-and-forth` is on (`layout.nix`), so pressing the number
of the workspace you are already on returns you to the previous one.

### Wheel, and the odds and ends

| Bind | Action |
| --- | --- |
| `Mod+Tab` | previous workspace |
| `Mod+Wheel` ↑↓ | focus workspace up / down |
| `Mod+Wheel` ←→ | focus column left / right |
| `Mod+Shift+Wheel` ↑↓ | move column to workspace up / down |
| `Mod+Shift+Wheel` ←→ | move column left / right |

Vertical wheel binds carry a 150 ms cooldown or one flick walks several
workspaces.

### Moving a single window, not the column

Every move bind acts on the whole **column**. To send one window out of a
stack, un-stack it first with `Mod+.` (expel) and then move it.

## Windows and layout

| Key | `Mod` | `Mod+Shift` | `Mod+Ctrl` |
| --- | --- | --- | --- |
| `q` | close window | — | — |
| `o` | overview | — | — |
| `a` | tabbed column display | — | — |
| `r` | cycle preset column width | cycle preset window height | reset window height |
| `f` | maximize column | fullscreen | expand column to available width |
| `c` | center column | — | center all visible columns |
| `w` | toggle floating | focus across floating ↔ tiling | sticky (pin above all workspaces) |
| `-` / `=` | width ∓10% | height ∓10% | — |

| Bind | Action |
| --- | --- |
| `Mod+[` / `Mod+]` | consume or expel window left / right |
| `Mod+,` / `Mod+.` | consume window into column / expel from column |

## Shell surfaces (DankMaterialShell)

| Key | `Mod` | `Mod+Shift` | `Mod+Ctrl` |
| --- | --- | --- | --- |
| `Space` | dankMenu root menu | — | — |
| `d` | dank dash | process list | control center |
| `n` | notifications | — | — |
| `v` | clipboard history | — | — |
| `p` | notepad | — | — |
| `/` | keybind cheat sheet | — | — |
| `m` | scratchpad (stash / restore) | — | — |

`Mod+Space` is the general launcher — the dankMenu root menu, with its own
search and app list. DMS's spotlight is still reachable for its
trigger-based plugins (see `Mod+Alt+E`).

`Mod+M` both stashes and restores: it is one toggle on scratchpad register 1,
not a pair of binds.

## Screen capture — the `s` family

| Bind | Action |
| --- | --- |
| `Mod+S` | region screenshot → DMS quickCapture annotation editor |
| `Mod+Shift+S` | region screenshot → clipboard (`grim`+`slurp`) |
| `Mod+Ctrl+S` | region OCR → clipboard (`tesseract`) |
| `Print` | niri's own screenshot UI |
| `Ctrl+Print` / `Alt+Print` | screenshot screen / window |
| `Mod+Print` | region screenshot → clipboard |

The `Print` rows need an external keyboard. The omnibook's internal keyboard
sends no Print keycode — the scissors key is a Windows "snip" key that emits
`Super+Shift+S` in firmware, so it lands on `Mod+Shift+S` and copies a region.
That is the intended result, so `Mod+Shift+S` should stay where it is.

## Apps

`Mod+T` terminal · `Mod+B` browser · `Mod+E` files.

Only these three get a bare `Mod+<letter>`. Everything else that merely runs
something lives one plane over, so `Mod+Shift` and `Mod+Ctrl` are never a
launcher.

## `Mod+Alt+<letter>` — run a tool

| Bind | Tool |
| --- | --- |
| `Mod+Alt+G` | lazygit |
| `Mod+Alt+M` | btop |
| `Mod+Alt+A` | phone screen mirror (`modules/apps/android.nix`) |
| `Mod+Alt+S` | colour picker (`hyprpicker`) |
| `Mod+Alt+T` | toggle light/dark theme |
| `Mod+Alt+W` | wallpaper picker |
| `Mod+Alt+N` | night light |
| `Mod+Alt+E` | emoji / unicode picker (also `Mod+F2`) |
| `Mod+Alt+P` | keydrill, with niri's own binds switched off while it runs |

**Bend #2:** `Mod+Alt+S` is a colour picker while `Mod+S` is capture. The
tool plane wins over the family rule when a key does both — the tool plane is
flat and unrelated by design.

`Mod+Alt` on a letter and `Mod+Alt` on a nav key never collide: they are
different key classes, and the nav keys `h j k l u i` and the number row are
not in the table above.

## Session

| Bind | Action |
| --- | --- |
| `Mod+BackSpace` | lock |
| `Mod+Shift+BackSpace` | lock, then suspend |
| `Mod+Ctrl+BackSpace` | power menu |
| `Mod+Alt+BackSpace` | power off monitors |
| `Mod+Escape` | toggle keyboard-shortcut inhibiting (works even while inhibited) |
| `Mod+Shift+Escape` | toggle practice mode — see below |
| `Ctrl+Alt+Delete` | quit niri |

`Ctrl+Alt+Delete` is the **only** bind that quits the compositor. There used
to be a `Mod+Shift+E` as well, one `Shift` away from `Mod+E` (the file
manager). It is gone.

## Practice mode

`Mod+Shift+Escape` switches every bind in this file off, so a shortcut
trainer sees the keys instead of the compositor. Press it again to switch
them back on — it is the one bind practice mode keeps, so you cannot strand
yourself. `Mod+Alt+P` does the same around keydrill and restores the binds
however it exits.

It works by config swap, not by inhibiting: `niri msg action load-config-file`
loads `~/.config/niri/practice.kdl`, which is this config with the binds
section replaced. Everything else — layout, input, window rules — is
identical, so nothing visibly rearranges.

`Mod+Escape` is a different thing and will not do this. It toggles the
Wayland keyboard-shortcuts-inhibit protocol, which only works for a client
that asked for an inhibitor; niri looks the focused surface up in
`keyboard_shortcuts_inhibiting_surfaces` and does nothing when it is absent.
Electron apps do not ask.

Owned by `practice.nix` and `_lib/practice-mode.sh`, not by `bindings.nix`.

## Hardware keys

Volume, mute, mic-mute, media transport and brightness are on their `XF86`
keys and need no modifier. Brightness drives the internal panel and both DDC
monitors in one call — see the comments in `bindings.nix`, they record the
i2c bus numbers and why the trailing `""` argument is mandatory.

`XF86Launch2` (the unlabeled F11 on this keyboard) toggles the on-screen
keyboard.

## Known upstream limitation

`Mod+Alt+<n>` and `Mod+Alt+U/I` pass `focus=false` to niri. niri ignores that
flag for **floating** windows, so moving a float still drags you to the
target workspace — [niri#1805](https://github.com/YaLTeR/niri/issues/1805).
Tiled windows are unaffected. Drop this section when the issue closes.

## Drilling these binds

`Mod+Alt+P` opens [keydrill](https://github.com/sitolam/keydrill) with the
binds switched off. It reads *this* config at runtime — there is no exported
deck to go stale — asks what a bind does, and waits for you to press it.

```sh
keydrill run --from niri              # everything
keydrill run --from niri -c Workspaces -n 15
keydrill stats --from niri            # learned, due, most forgotten
```

Wheel binds and the `XF86` keys are skipped; you cannot drill a scroll
gesture. An action keydrill has no phrasing for keeps its raw name as the
prompt, so a gap shows up rather than going missing.

## Changing a bind

Nav planes: edit the `mkBinds` / `mkNumberBinds` / `mkScrollBinds` call in
`bindings.nix` — never add a one-off `Mod+Shift+Left` next to it, or the two
key sets drift apart.

Everything else: put it on the key whose `Mod` bind it is a variant of, or on
the `Mod+Alt` tool plane. If it fits neither, it probably belongs in the
dankMenu root menu (`../dms/plugins.nix`) rather than on a key.

A module that owns a feature may add its own bind from its own file — see
`modules/apps/android.nix`. The grammar still applies there.
