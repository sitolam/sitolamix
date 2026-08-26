# dms-plugins monorepo and dankMenu, an omarchy-menu for DMS

**Date:** 2026-08-21
**Status:** implemented

## Problem

Two things, one change.

**First**, `sitolam/dms-mouthguard` is a one-plugin repo. It is pinned as its
own flake input (`flake.nix:100`), assembled by hand in
`modules/desktop/dms/plugins.nix`, and there is nowhere for a *second*
home-grown DMS plugin to live. Every new plugin would repeat the whole
input-plus-assembly ritual.

**Second**, Omarchy binds `SUPER + SPACE` to `omarchy-menu toggle`
(`default/hypr/bindings/utilities.lua:1`) — a hierarchical, fuzzy-searchable
command menu covering Apps, Learn, Trigger, Style, Setup, Install, Remove,
Update, About and System. It is the single entry point to the whole desktop:
one key, then type or arrow to anything. DMS has no equivalent. Its spotlight
is an app launcher with plugin-contributed rows, not a navigable command tree.

Goal: a `dms-plugins` repo holding both plugins, and a new self-contained DMS
plugin that reproduces the omarchy-menu experience — including its own app
search, written fresh rather than delegating to DMS's spotlight.

## Decisions taken

These were settled before design and are not open:

- The menu is a **standalone plugin window**, not a spotlight launcher plugin.
- Its search, including app search, is **built into the plugin**. Nothing calls
  into `DankLauncherV2` or the spotlight IPC surface.
- The plugin ships a **default tree as JSONC**, overridable from Nix.
- **Full** `when` / `checked` / `disabled` condition support, as omarchy has.
- Name: **`dankMenu`** (dir `plugins/dankmenu`, plugin id and IPC target
  `dankMenu`).
- Bound to **`Mod+Space`**; the existing spotlight binds are dropped.
- Mouthguard moves **with its git history intact**.

## Why not a launcher plugin

Worth recording, because it looks like the obvious answer and is not.

DMS supports `type: launcher` plugins that contribute rows to spotlight
(`quickshell/PLUGINS/README.md:1258`), and an empty-trigger plugin's rows do
appear at an empty query alongside apps
(`Controller._performPluginPhase`, `quickshell/Modals/DankLauncherV2/Controller.qml:990`).
That would have given menu-as-spotlight-root for free.

It fails on navigation. `Controller.executeItem` ends by emitting
`itemExecuted` (`Controller.qml:2016`), and `SpotlightLauncherContent.qml:225`
hides the modal on that signal unconditionally. There is no plugin hook to keep
the modal open, so "Enter drills into a submenu" cannot work — selecting a row
always closes the launcher. The only workaround is re-summoning spotlight with
the path stuffed into the query via
`PopoutService.openDankLauncherV2WithQuery` (`quickshell/DMSShellIPC.qml:1504`),
which flickers once per level and leans on a host internal.

An owned window has none of that. The precedent is `screenCaptureToolbar`,
already enabled here: `type: daemon`, `capabilities: ["ipc"]`, its own
`PanelWindow`.

## Repository layout

```
dms-plugins/
├── flake.nix
├── README.md
└── plugins/
    ├── mouthguard/
    │   └── (every current file, paths unchanged relative to the plugin root)
    └── dankmenu/
        ├── plugin.json
        ├── DankMenuDaemon.qml
        ├── MenuWindow.qml
        ├── MenuList.qml
        ├── DankMenuSettings.qml
        ├── menu.jsonc
        ├── MenuModel.js
        ├── Search.js
        ├── Conditions.qml
        └── AppSource.qml
```

Plugin roots stay self-contained: DMS symlinks one directory per plugin into
`~/.config/DankMaterialShell/plugins/<id>` (`distro/nix/home.nix:120`), so
nothing inside a plugin may reference a path above its own root. Mouthguard's
internal layout therefore does not change at all — only the prefix it sits
under.

The flake exposes, per system:

- `packages.mouthguard-detector` — what `dms-mouthguard`'s flake called
  `detector`, kept so the existing name-based workflow still resolves.
- `packages.dankmenu` and `packages.mouthguard` — plain directory derivations
  for the plugin sources, so consumers can use `inputs.dms-plugins.packages.…`
  instead of string-interpolating a subpath.
- `devShells.default` — mouthguard's current shell, unchanged, including the
  `QML_IMPORT_PATH` hook it needs for `qmltestrunner`.
- `checks` — mouthguard's pytest suite plus QML tests for dankMenu.

### Migrating mouthguard with history

```
git clone https://github.com/sitolam/dms-mouthguard /tmp/mg
cd /tmp/mg && git filter-repo --to-subdirectory-filter plugins/mouthguard
```

then, in the fresh `dms-plugins` repo, add `/tmp/mg` as a remote and merge it
with `--allow-unrelated-histories`. Result: every mouthguard commit is present,
with its paths rewritten under `plugins/mouthguard/`, and `git log --follow` on
any file works.

`git-filter-repo` is not in this config's package set; the migration runs it
from `nix run nixpkgs#git-filter-repo`, which needs no permanent install.

The old repo is **archived on GitHub, not deleted** — the flake lock of any
older generation still references it.

## dankMenu

### Manifest and surfaces

```json
{
  "id": "dankMenu",
  "type": "daemon",
  "capabilities": ["ipc"],
  "component": "./DankMenuDaemon.qml",
  "settings": "./DankMenuSettings.qml",
  "permissions": ["process", "settings_read", "settings_write"]
}
```

`DankMenuDaemon.qml` is a `PluginComponent` holding an `IpcHandler` and a
`LazyLoader` for the window, so nothing heavier than the handler exists until
the menu is first opened. The IPC verbs mirror `omarchy-menu`'s, deliberately,
so muscle memory and scripts port:

| verb | argument | behaviour |
| --- | --- | --- |
| `toggle` | route, default `root` | open at route, or close if already visible |
| `open` | route, default `root` | always open (no close-if-visible) |
| `close` | — | close if visible |
| `refresh` | — | re-read the menu file and drop caches |

A route is a dotted id (`setup.network`) or an alias (`power`), resolved by
`MenuModel.js`; an unresolvable route opens the root and warns.

### The menu file

`menu.jsonc` uses omarchy's schema verbatim — object keys are dotted ids that
imply hierarchy, and the row kind is inferred: `action` makes an action,
`target` a link, `provider` a provider-backed submenu, anything else a plain
submenu. Recognised fields: `icon`, `iconFont`, `label`, `title`, `aliases`,
`action`, `target`, `provider`, `when`, `checked`, `disabled`.

Keeping the schema identical is a deliberate cheap option: any subtree of
omarchy's own `omarchy-menu.jsonc` can be pasted in and will parse, even though
the default tree shipped here is written for niri and NixOS rather than
Hyprland and pacman.

JSONC is parsed by a small stripper in `MenuModel.js` (line and block comments
outside strings, then trailing commas) followed by `JSON.parse`. Qt has no
JSONC reader; this is why the parser is ours.

`MenuModel.js` builds the tree once per parse: a map of id to node, each node
carrying its children in file order, and an alias index. It exposes
`resolve(route)`, `childrenOf(id)`, `leavesUnder(id)` and `breadcrumb(id)`.

**Override.** The plugin setting `menuPath` (default `""`) names a file to read
instead of the bundled one. A `FileView` watches whichever file is live and
reparses on change, so editing the tree does not need a shell restart. This is
what lets the tree be Nix-generated while the plugin stays useful to anyone who
installs it from the repo.

### Window and navigation

`MenuWindow.qml` is a `PanelWindow` with `WlrLayershell.layer: Overlay`,
`WlrLayershell.exclusiveZone: -1`, `WlrLayershell.keyboardFocus: Exclusive`
while visible and `None` otherwise, and a namespace of
`dms:plugins:dankMenu` — matching the pattern at
`CaptureToolbar.qml:1041`. A dimmed backdrop covers the screen; the menu itself
is a centred rounded card holding a header (icon, breadcrumb title), a search
field, and the list.

Chrome comes from DMS itself: `Theme` from `qs.Common`, and `DankListView`,
`DankTextField`, `DankIcon`, `StyledText` from `qs.Widgets`. The menu inherits
the active theme, so it tracks the Catppuccin config in
`modules/desktop/dms/theme.nix` with no work.

Keys:

| key | effect |
| --- | --- |
| `Enter` / `Right` | drill into a submenu, or run a leaf and close |
| `Esc` / `Left` | pop one level; at root, close |
| `Backspace` on an empty query | pop one level |
| `Up` / `Down`, `Ctrl+P` / `Ctrl+N` | move selection |
| any text | filter |

Entering or leaving a level clears the query, as omarchy does — the query
belongs to the level, not the session.

### Search

`Search.js` is written for this plugin. It scores a query against a row's
label, comment and aliases with: subsequence match as the gate, then bonuses
for contiguous runs, matches at word boundaries, and a whole-string prefix;
label matches outrank comment matches, which outrank alias matches. Ties break
on file order so an unfiltered level always reads in the order the tree
declares.

Scope is the **current subtree, recursively**. At `setup.network` a query only
sees network rows; at root it sees every leaf in the tree, each shown with its
breadcrumb as the subtitle. That makes the root a genuine command palette
without a separate "search everything" mode.

### Apps

`AppSource.qml` reads `DesktopEntries.applications.values` — the same source
DMS's own service uses (`quickshell/Services/AppSearchService.qml:52`) — and
maps entries to menu items. They are ranked by `Search.js` plus a frecency
term read from `AppUsageHistoryData`, so recently and frequently used apps
float up.

Apps appear in two places: under the `apps` provider row (an omarchy-style
`Apps` submenu, browsable), and mixed into root-level search results, so typing
a program name at root finds it without visiting the submenu first.

Launching calls `SessionService.launchDesktopEntry(entry)` followed by
`AppUsageHistoryData.addAppUsage(entry)` — the same two calls
`Controller.launchApp` makes (`Controller.qml:2090`). This is a launch
primitive, not spotlight's search: it exists so that scope handling (uwsm,
systemd scopes, terminal entries) is correct rather than reimplemented wrongly.
No part of the search, ranking or UI comes from `DankLauncherV2`.

### Conditions

Omarchy rows may carry three shell snippets: `when` (hide the row unless it
succeeds), `checked` (append a tick when it succeeds) and `disabled` (dim,
tick, and make unselectable when it succeeds).

Evaluating one process per row would mean dozens of spawns per keystroke-free
open. Instead `Conditions.qml` generates, per level entered, a **single** bash
script containing every snippet for that level's rows, each wrapped so its exit
status is printed:

```
{ <snippet> ; } >/dev/null 2>&1; printf '%s\t%s\t%s\n' "<id>" "when" "$?"
```

One `Process` runs it; output is parsed line by line into a per-id result map.
Rows render in a neutral pending state and settle when the map arrives, so a
slow condition never blocks the window from appearing. Results are cached for
the lifetime of one menu open and dropped on close or `refresh`.

A row with no conditions costs nothing — it never reaches the script.

### Actions

`action` runs through `Process` as `bash -lc "<action>"`, detached, and the
menu closes. `bash -lc` rather than plain exec because omarchy's actions are
shell text: they use pipes, `$(…)`, `&&` and quoting freely, and the schema
compatibility above is only real if that keeps working.

`target` opens through `Qt.openUrlExternally`.

## The default tree

Omarchy's tree is Arch and Hyprland shaped: `install` and `remove` drive
`pacman`, most of `setup` edits `~/.config/hypr/*.lua`, and `style` mutates
files a NixOS generation would overwrite. Porting it row for row would ship
entries that cannot work here. The default tree is therefore written for this
machine, keeping omarchy's *shape* — same top-level spine, same verbs — and
replacing the mechanism underneath.

Top level, with what each is backed by:

| row | contents |
| --- | --- |
| `apps` | `provider: apps` — the built-in desktop-entry list |
| `learn` | links: niri wiki, NixOS manual, Home Manager options, nixpkgs search; plus a Keybinds row calling `dms ipc call keybinds toggleBinds` |
| `trigger` | capture (`dms ipc call screenCaptureToolbar toggle`), emoji, clipboard (`dms ipc call clipboard toggle`), notepad, and a `toggle` submenu for idle inhibit, do-not-disturb and night mode |
| `style` | theme and wallpaper switching through DMS's own IPC, and bar transparency — runtime state only, never files Nix owns |
| `setup` | opens this config in the editor, `niri msg outputs`, network and audio panels |
| `update` | `just update`, `just rebuild`, `just diff`, `just dms-reload`, each in a floating terminal so output is visible |
| `system` | lock, suspend, logout, reboot, shutdown |

`install` and `remove` are deliberately absent: adding a package here means
editing the flake, which `setup` already opens.

The `update` rows run against the flake checkout, whose path is interpolated
from Nix rather than assumed — this is one of the reasons the tree is
Nix-generated rather than a static file.

This table is the starting set, not a contract; the implementation plan pins
each row to a verified command before it ships.

## Wiring into sitolamix

`flake.nix`: the `dms-mouthguard` input becomes `dms-plugins`, url
`github:sitolam/dms-plugins`, `inputs.nixpkgs.follows = "nixpkgs"` as now.

`modules/desktop/dms/plugins.nix`:

- Everything in the `let` block that builds mouthguard stays as it is, with
  `${inputs.dms-mouthguard}` becoming `${inputs.dms-plugins}/plugins/mouthguard`.
  The dlib 20.0 pin, the `result` symlink trick and their comments are
  unchanged — nothing about the move alters why they exist.
- A new `dankMenu` entry: `enable = true`, `src =
  "${inputs.dms-plugins}/plugins/dankmenu"`, `settings.menuPath` pointing at a
  Nix-generated JSON tree. Arbitrary plugin ids are supported — `plugins` is
  `attrsOf (submodule { enable; src; settings; })` with no registry constraint
  (`distro/nix/options.nix:84`) — which is exactly how mouthGuard already works.
- The tree itself is built in Nix so entries can interpolate store paths and
  reference this config's own scripts rather than hard-coded binary names.

`modules/desktop/niri/bindings.nix`: `Mod+Space` becomes
`dms ipc call dankMenu toggle root`. The `Mod+Ctrl+Return` spotlight alias is
removed.

## Known consequence: spotlight-hosted plugins

`calculator` (trigger `=`) and `emojiLauncher` (trigger `:e`) are launcher
plugins that only exist inside spotlight. With both general spotlight binds
gone, `Mod+Shift+Period` — which calls `spotlight toggleQuery ":e "`
(`bindings.nix:99`) — becomes the only remaining door into spotlight. Emoji
therefore still works; the calculator becomes unreachable.

This is left as a follow-up decision, not resolved here. The options are: keep
a spotlight bind purely for it, drop the plugin, or add a calculator row to
dankMenu later. Nothing in this design forecloses any of them.

## Testing

- `MenuModel.js` and `Search.js` are plain JavaScript with no Qt dependencies,
  so they are unit-tested directly: JSONC edge cases (comments inside strings,
  trailing commas, `//` inside a URL), tree construction from dotted ids, route
  and alias resolution, and scorer ordering guarantees.
- `Conditions.qml` script generation is tested against a fixture tree: the
  generated script text is asserted, and parsing is tested against captured
  output including a row whose snippet writes to stdout.
- Window behaviour — drill in, pop, close, route opening — via `qmltestrunner`
  in the flake's dev shell, which mouthguard already sets up.
- Mouthguard's existing pytest suite must still pass unchanged after the move;
  that is the migration's acceptance test.
- Manual: rebuild, `Mod+Space`, walk the tree, confirm ticks appear on
  conditioned rows and that a laptop-only row is absent on this desktop.
