# dms-plugins monorepo + dankMenu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `sitolam/dms-plugins`, move MouthGuard into it with history intact, and add `dankMenu` — a DankMaterialShell plugin reproducing Omarchy's `SUPER+SPACE` menu, with its own window, its own search, and its own app list.

**Architecture:** `dankMenu` is a `type: daemon` DMS plugin exposing an `IpcHandler` and owning a wlr-layershell `PanelWindow`. All logic that can be pure JavaScript is pure JavaScript (`MenuModel.js`, `Search.js`, `Conditions.js`) so it is unit-testable with `qmltestrunner` without a running shell; the QML files are thin shells over those modules. The menu tree is JSONC in Omarchy's exact schema, overridable by a Nix-generated file.

**Tech Stack:** QML (Quickshell / DankMaterialShell ≥1.5.3), plain JavaScript modules, `qmltestrunner` (Qt Quick Test), `pytest` (MouthGuard's existing suite), Nix flakes, `git-filter-repo` for the history-preserving move.

**Spec:** `docs/superpowers/specs/2026-08-21-dms-plugins-dankmenu-design.md`

## Global Constraints

- Plugin id, IPC target and Nix attribute name are all exactly `dankMenu`. Directory is `plugins/dankmenu` (lowercase).
- `requires_dms` is `>=1.5.0`.
- A plugin directory is symlinked whole into `~/.config/DankMaterialShell/plugins/<id>`. **Nothing inside a plugin may reference a path above its own root.**
- MouthGuard's files keep their paths *relative to the plugin root*. The move adds a prefix and changes nothing else.
- Menu file schema is Omarchy's, field-for-field: `icon`, `iconFont`, `label`, `title`, `aliases`, `action`, `target`, `provider`, `when`, `checked`, `disabled`. Object keys are dotted ids; hierarchy is implied by the dots.
- Kind inference order, from Omarchy: `action` → action, `target` → link, `provider` → provider, otherwise submenu.
- Nothing may import, call, or otherwise depend on `DankLauncherV2`, `AppSearchService`, or the `spotlight` IPC target. The single permitted reuse is `SessionService.launchDesktopEntry` plus `AppUsageHistoryData.addAppUsage`, which are launch primitives, not search.
- `qmltestrunner` accepts **one** `-input` file per run, and its exit code is the **failure count**, not a flat `1`.
- Verified DMS APIs available to plugins: `PluginComponent` (from `qs.Modules.Plugins`) supplying `pluginId`, `pluginService` and `pluginData`; `Theme` (from `qs.Common`) supplying `primary`, `surface`, `surfaceText`, `surfaceVariantText`, `surfaceContainer`, `surfaceContainerHigh`, `outline`, `error`, `cornerRadius`, `spacingXS/S/M/L/XL`, `fontSizeSmall/Medium/Large`; `DankIcon { name; size; color }` and `StyledText { text; color; font.pixelSize }` (from `qs.Widgets`).
- Local checkout for the new repo: `~/Documents/dms-plugins` (beside the existing `~/Documents/dms-mouthguard`).

---

## File Structure

**New repo `~/Documents/dms-plugins`:**

| Path | Responsibility |
| --- | --- |
| `flake.nix` | dev shell, `mouthguard-detector` package, plugin source packages, checks |
| `README.md` | what the repo holds, per-plugin install |
| `plugins/mouthguard/**` | migrated unchanged |
| `plugins/dankmenu/plugin.json` | manifest |
| `plugins/dankmenu/MenuModel.js` | JSONC parse, tree build, route resolution — no Qt |
| `plugins/dankmenu/Search.js` | fuzzy scoring and ranking — no Qt |
| `plugins/dankmenu/Conditions.js` | condition script generation and output parsing — no Qt |
| `plugins/dankmenu/DankMenuDaemon.qml` | `PluginComponent`: IPC handler, tree loading, window lifecycle |
| `plugins/dankmenu/MenuWindow.qml` | layershell window, backdrop, header, search field, key handling |
| `plugins/dankmenu/MenuList.qml` | list view and row delegate |
| `plugins/dankmenu/Conditions.qml` | runs the generated script, owns the result cache |
| `plugins/dankmenu/AppSource.qml` | `DesktopEntries` → menu items, launching |
| `plugins/dankmenu/DankMenuSettings.qml` | settings UI (`menuPath`, width, app-search toggle) |
| `plugins/dankmenu/menu.jsonc` | default tree |
| `plugins/dankmenu/tests/tst_menumodel.qml` | `MenuModel.js` tests |
| `plugins/dankmenu/tests/tst_search.qml` | `Search.js` tests |
| `plugins/dankmenu/tests/tst_conditions.qml` | `Conditions.js` tests |

**Modified in `~/sitolamix`:**

| Path | Change |
| --- | --- |
| `flake.nix:100-104` | input `dms-mouthguard` → `dms-plugins` |
| `modules/desktop/dms/plugins.nix` | MouthGuard source path; new `dankMenu` entry; Nix-generated tree |
| `modules/desktop/niri/bindings.nix:71-79` | `Mod+Space` → dankMenu; drop the spotlight alias |

---

## Task 1: Create the repo and migrate MouthGuard with history

**Files:**
- Create: `~/Documents/dms-plugins/` (new git repo, new GitHub repo)
- Create: `~/Documents/dms-plugins/README.md`
- Create: `~/Documents/dms-plugins/flake.nix`
- Migrate: every file of `sitolam/dms-mouthguard` → `plugins/mouthguard/`

**Interfaces:**
- Produces: flake outputs `packages.<system>.mouthguard-detector`, `packages.<system>.mouthguard`, `devShells.<system>.default`. Every later task's test commands run inside `nix develop`.

- [ ] **Step 1: Rewrite MouthGuard's history into a subdirectory**

```bash
rm -rf /tmp/mg-migrate
git clone https://github.com/sitolam/dms-mouthguard /tmp/mg-migrate
cd /tmp/mg-migrate
nix run nixpkgs#git-filter-repo -- --to-subdirectory-filter plugins/mouthguard
```

- [ ] **Step 2: Verify the rewrite kept every commit and moved every path**

```bash
cd /tmp/mg-migrate
git log --oneline | wc -l          # must equal the original repo's commit count
git ls-files | grep -cv '^plugins/mouthguard/'   # must print 0
git log --oneline -- plugins/mouthguard/detector.py | wc -l   # must be > 1
```

Expected: same commit count as `git -C ~/Documents/dms-mouthguard log --oneline | wc -l`, zero files outside the prefix, and detector.py's history intact.

- [ ] **Step 3: Create the new repo and merge that history in**

```bash
mkdir -p ~/Documents/dms-plugins && cd ~/Documents/dms-plugins
git init -b main
git commit -q --allow-empty -m "chore: initial commit"
git remote add mouthguard /tmp/mg-migrate
git fetch mouthguard
git merge --allow-unrelated-histories --no-edit mouthguard/main
git remote remove mouthguard
```

- [ ] **Step 4: Verify the merge**

```bash
cd ~/Documents/dms-plugins
ls plugins/mouthguard/plugin.json
git log --follow --oneline plugins/mouthguard/detector.py | tail -3
```

Expected: the manifest exists, and `--follow` reaches MouthGuard's earliest detector commits.

- [ ] **Step 5: Write the flake**

`~/Documents/dms-plugins/flake.nix` — MouthGuard's flake with paths reprefixed, plus plugin-source packages. Keep the `shellHook` comment from the original; the reason it exists has not changed.

```nix
{
  description = "sitolam's DankMaterialShell plugins";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in
    {
      packages = forAll (pkgs: rec {
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          dlib opencv4 numpy face-recognition-models
        ]);

        detectorSrc = pkgs.runCommand "mouthguard-detector-src" { } ''
          mkdir -p $out
          cp ${./plugins/mouthguard/detector.py} $out/detector.py
          cp ${./plugins/mouthguard/mouthguard_core.py} $out/mouthguard_core.py
        '';

        mouthguard-detector = pkgs.writeShellScriptBin "mouthguard-detector" ''
          exec ${pythonEnv}/bin/python3 ${detectorSrc}/detector.py "$@"
        '';

        # Plugin source trees, so consumers can take a package rather than
        # interpolating a subpath of the flake input.
        mouthguard = pkgs.runCommand "dms-plugin-mouthguard-src" { } ''
          cp -r ${./plugins/mouthguard} $out
        '';
        dankmenu = pkgs.runCommand "dms-plugin-dankmenu-src" { } ''
          cp -r ${./plugins/dankmenu} $out
        '';

        default = mouthguard-detector;
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
            (pkgs.python3.withPackages (ps: with ps; [
              dlib opencv4 numpy face-recognition-models pytest
            ]))
            pkgs.qt6.qtdeclarative
            pkgs.jq
          ];

          # qmltestrunner's bundled QtTest/TestCase.qml imports QtQuick.Window,
          # which lives in qtdeclarative's own qml tree. That tree isn't on the
          # import path by default in this shell (and an ambient system Qt
          # install can shadow it), so qmltestrunner fails to resolve TestCase
          # itself. Point both the Qt6 and legacy Qt5-named variables at it.
          shellHook = ''
            export QML_IMPORT_PATH="${pkgs.qt6.qtdeclarative}/lib/qt-6/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
            export QML2_IMPORT_PATH="$QML_IMPORT_PATH"
          '';
        };
      });
    };
}
```

Note: `plugins/dankmenu` does not exist yet, so this flake does not evaluate until Task 2 creates it. That is why Step 6 only checks the dev shell, and `nix flake check` waits for Task 2.

- [ ] **Step 6: Create `plugins/dankmenu` as a placeholder so the flake evaluates**

```bash
cd ~/Documents/dms-plugins
mkdir -p plugins/dankmenu
printf '{}\n' > plugins/dankmenu/.keep
```

- [ ] **Step 7: Verify MouthGuard still works after the move**

```bash
cd ~/Documents/dms-plugins/plugins/mouthguard
nix develop ../.. -c pytest
```

Expected: `33 passed` — the same count the pre-move repo reports. This is the migration's acceptance test.

- [ ] **Step 8: Verify the QML tests and the detector build**

```bash
cd ~/Documents/dms-plugins
nix develop -c qmltestrunner -input plugins/mouthguard/tests/tst_statemachine.qml
nix develop -c qmltestrunner -input plugins/mouthguard/tests/tst_gapchart_math.qml
nix build .#mouthguard-detector
./result/bin/mouthguard-detector --help
```

Expected: both test runs report passes and exit 0; the detector builds and prints usage.

- [ ] **Step 9: Write the README**

`~/Documents/dms-plugins/README.md`:

```markdown
# dms-plugins

DankMaterialShell plugins written for [sitolamix](https://github.com/sitolam/sitolamix).

| Plugin | What it does |
| --- | --- |
| [`mouthguard`](plugins/mouthguard) | Webcam mouth-closure tracker with alerts and session stats |
| [`dankmenu`](plugins/dankmenu) | Omarchy-style root menu: one key to every command, with its own search |

Each directory under `plugins/` is a complete DMS plugin and is symlinked whole
into `~/.config/DankMaterialShell/plugins/<id>`; nothing in a plugin references
a path above its own root.

## Install

Manually:

    ln -s "$PWD/plugins/dankmenu" ~/.config/DankMaterialShell/plugins/dankMenu

On NixOS, via home-manager:

    programs.dank-material-shell.plugins.dankMenu = {
      enable = true;
      src = inputs.dms-plugins.packages.${pkgs.system}.dankmenu;
    };

## Development

    nix develop
    pytest plugins/mouthguard              # MouthGuard's Python suite
    qmltestrunner -input plugins/dankmenu/tests/tst_menumodel.qml

`qmltestrunner` takes one `-input` file per run, and its exit code is the
failure count rather than a flat 1.
```

- [ ] **Step 10: Commit and publish**

```bash
cd ~/Documents/dms-plugins
git add flake.nix README.md plugins/dankmenu/.keep
git commit -m "feat: monorepo for sitolam's DMS plugins

MouthGuard moves in under plugins/mouthguard with its history rewritten
into that prefix, so git log --follow still works. The flake keeps the
detector package and dev shell it had, and gains plugin-source packages
so consumers take a package instead of interpolating a subpath."
gh repo create sitolam/dms-plugins --public --source=. --remote=origin --push \
  --description "DankMaterialShell plugins: mouthguard, dankmenu"
```

- [ ] **Step 11: Archive the old repo**

```bash
gh repo archive sitolam/dms-mouthguard --yes
```

Archive rather than delete: older generations' flake locks still reference it.

---

## Task 2: dankMenu skeleton — manifest, daemon, IPC, empty window

**Files:**
- Create: `plugins/dankmenu/plugin.json`
- Create: `plugins/dankmenu/DankMenuDaemon.qml`
- Create: `plugins/dankmenu/MenuWindow.qml`
- Delete: `plugins/dankmenu/.keep`

**Interfaces:**
- Produces: IPC target `dankMenu` with `toggle(route)`, `open(route)`, `close()`, `refresh()`. `MenuWindow` exposes `property bool menuVisible`, `function openAt(route)`, `function closeMenu()`, and `signal closed()`.

- [ ] **Step 1: Write the manifest**

`plugins/dankmenu/plugin.json`:

```json
{
    "id": "dankMenu",
    "name": "Dank Menu",
    "description": "Omarchy-style root menu: one key to every command, with built-in search",
    "version": "0.1.0",
    "license": "MIT",
    "author": "sitolam",
    "icon": "menu_open",
    "type": "daemon",
    "capabilities": ["daemon", "ipc"],
    "component": "./DankMenuDaemon.qml",
    "settings": "./DankMenuSettings.qml",
    "requires_dms": ">=1.5.0",
    "compositors": ["any"],
    "permissions": ["settings_read", "settings_write", "process"]
}
```

`DankMenuSettings.qml` arrives in Task 11; DMS tolerates the key pointing at a
file that does not exist yet only in the sense that the settings pane will be
empty, so do not enable the plugin in the shell until that task lands.

- [ ] **Step 2: Write the daemon**

`plugins/dankmenu/DankMenuDaemon.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var popoutService: null

    // The window is created on first open, not at shell startup: a daemon
    // plugin is instantiated with the shell, and an unopened menu should cost
    // nothing but this handler.
    LazyLoader {
        id: windowLoader
        loading: false
        component: MenuWindow {
            onClosed: windowLoader.loading = false
        }
    }

    function openAt(route) {
        windowLoader.loading = true;
        windowLoader.item.openAt(route || "root");
    }

    function closeMenu() {
        if (windowLoader.item)
            windowLoader.item.closeMenu();
    }

    readonly property bool menuVisible: windowLoader.item ? windowLoader.item.menuVisible : false

    IpcHandler {
        target: "dankMenu"

        function toggle(route: string): string {
            if (root.menuVisible) {
                root.closeMenu();
                return "DANKMENU_CLOSED";
            }
            root.openAt(route);
            return "DANKMENU_OPENED: " + (route || "root");
        }

        function open(route: string): string {
            root.openAt(route);
            return "DANKMENU_OPENED: " + (route || "root");
        }

        function close(): string {
            root.closeMenu();
            return "DANKMENU_CLOSED";
        }

        function refresh(): string {
            return "DANKMENU_REFRESHED";
        }
    }
}
```

`refresh` is a stub until Task 11 gives it a tree to reload.

- [ ] **Step 3: Write the window shell**

`plugins/dankmenu/MenuWindow.qml` — the layershell surface and nothing else yet.

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: root

    property bool menuVisible: false
    property string pendingRoute: "root"

    signal closed

    function openAt(route) {
        pendingRoute = route || "root";
        menuVisible = true;
    }

    function closeMenu() {
        menuVisible = false;
        closed();
    }

    visible: menuVisible
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "dms:plugins:dankMenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: menuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Dimmed backdrop; clicking it closes, as Omarchy's menu does.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeMenu()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(720, parent.width - Theme.spacingXL * 2)
        height: Math.min(520, parent.height - Theme.spacingXL * 2)
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outline

        // Swallow clicks so they don't reach the backdrop.
        MouseArea {
            anchors.fill: parent
        }
    }

    Item {
        anchors.fill: parent
        focus: root.menuVisible

        Keys.onEscapePressed: root.closeMenu()
    }
}
```

- [ ] **Step 4: Install the plugin into the live shell and verify it loads**

```bash
rm -f ~/Documents/dms-plugins/plugins/dankmenu/.keep
ln -sfn ~/Documents/dms-plugins/plugins/dankmenu ~/.config/DankMaterialShell/plugins/dankMenu
dms ipc call plugins reload dankMenu
```

Expected: no QML errors in `journalctl --user -u dms -n 40`.

This symlink is a **development** install, deliberately outside Nix: the Nix
wiring in Task 13 is what makes it permanent. `managePluginSettings = true` in
this config makes `plugin_settings.json` read-only, so the plugin must be
enabled by hand for now via the DMS plugin browser.

- [ ] **Step 5: Verify IPC opens and closes the window**

```bash
dms ipc call dankMenu open root      # expect DANKMENU_OPENED: root
dms ipc call dankMenu close          # expect DANKMENU_CLOSED
dms ipc call dankMenu toggle root    # expect DANKMENU_OPENED: root
dms ipc call dankMenu toggle root    # expect DANKMENU_CLOSED
```

Expected: an empty dimmed card appears and disappears; Escape closes it.

- [ ] **Step 6: Commit**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu
git rm --cached plugins/dankmenu/.keep 2>/dev/null || true
git commit -m "feat(dankmenu): plugin skeleton with IPC-driven layershell window

Daemon plugin owning its own overlay window rather than a spotlight
launcher plugin: DMS hides the spotlight modal on every itemExecuted
with no plugin hook to prevent it, so drill-in navigation is impossible
there. Verbs mirror omarchy-menu's so routes and muscle memory port."
```

---

## Task 3: `MenuModel.js` — JSONC parsing and tree construction

**Files:**
- Create: `plugins/dankmenu/MenuModel.js`
- Test: `plugins/dankmenu/tests/tst_menumodel.qml`

**Interfaces:**
- Produces:
  - `stripComments(text) -> string`
  - `stripTrailingCommas(text) -> string`
  - `parse(text) -> tree`
  - `build(obj) -> tree` where `tree = { nodes, roots, aliases, orphans }`, `nodes[id] = { id, parent, icon, iconFont, label, title, aliases, action, target, provider, when, checked, disabled, children }`
  - `kindOf(node) -> "action" | "link" | "provider" | "submenu"`
  - `resolve(tree, route) -> id | ""` (`""` means the root level)
  - `childrenOf(tree, id) -> [node]`
  - `breadcrumb(tree, id) -> [string]`
  - `leavesUnder(tree, id) -> [node]`

- [ ] **Step 1: Write the failing test**

`plugins/dankmenu/tests/tst_menumodel.qml`:

```qml
import QtQuick
import QtTest
import "../MenuModel.js" as MenuModel

// MenuModel.js has no QML types, no Theme and no Quickshell imports, so the
// exact file the plugin loads is exercised here rather than a copy.
TestCase {
    name: "MenuModel"

    function test_strip_line_comment() {
        const src = '{\n  // a comment\n  "a": {"label":"A"}\n}';
        compare(JSON.parse(MenuModel.stripComments(src)).a.label, "A");
    }

    function test_strip_block_comment() {
        const src = '{ /* gone\n still gone */ "a": {"label":"A"} }';
        compare(JSON.parse(MenuModel.stripComments(src)).a.label, "A");
    }

    function test_keeps_double_slash_inside_string() {
        const src = '{ "a": {"target":"https://omarchy.org/manual/"} }';
        const out = JSON.parse(MenuModel.stripComments(src));
        compare(out.a.target, "https://omarchy.org/manual/");
    }

    function test_keeps_escaped_quote_inside_string() {
        const src = '{ "a": {"label":"say \\"hi\\" // now"} }';
        const out = JSON.parse(MenuModel.stripComments(src));
        compare(out.a.label, 'say "hi" // now');
    }

    function test_strip_trailing_comma_object_and_array() {
        const src = '{ "a": {"aliases":["x","y",],}, }';
        const out = JSON.parse(MenuModel.stripTrailingCommas(src));
        compare(out.a.aliases.length, 2);
    }

    function test_keeps_comma_inside_string() {
        const src = '{ "a": {"label":"one, two"} }';
        const out = JSON.parse(MenuModel.stripTrailingCommas(src));
        compare(out.a.label, "one, two");
    }

    property string sample: '{\n'
        + '  // root\n'
        + '  "system": {"icon":"","label":"System","aliases":["power-menu"]},\n'
        + '  "system.lock": {"icon":"","label":"Lock","action":"loginctl lock-session"},\n'
        + '  "system.reboot": {"label":"Reboot","action":"systemctl reboot","when":"true"},\n'
        + '  "learn": {"label":"Learn"},\n'
        + '  "learn.niri": {"label":"Niri","target":"https://github.com/YaLTeR/niri/wiki"},\n'
        + '  "apps": {"label":"Apps","provider":"apps"},\n'
        + '}';

    function test_build_roots_in_file_order() {
        const tree = MenuModel.parse(sample);
        compare(tree.roots, ["system", "learn", "apps"]);
    }

    function test_build_children_from_dotted_ids() {
        const tree = MenuModel.parse(sample);
        compare(tree.nodes["system"].children, ["system.lock", "system.reboot"]);
    }

    function test_kind_inference() {
        const tree = MenuModel.parse(sample);
        compare(MenuModel.kindOf(tree.nodes["system.lock"]), "action");
        compare(MenuModel.kindOf(tree.nodes["learn.niri"]), "link");
        compare(MenuModel.kindOf(tree.nodes["apps"]), "provider");
        compare(MenuModel.kindOf(tree.nodes["learn"]), "submenu");
    }

    function test_resolve_by_id_alias_and_root() {
        const tree = MenuModel.parse(sample);
        compare(MenuModel.resolve(tree, "system.lock"), "system.lock");
        compare(MenuModel.resolve(tree, "power-menu"), "system");
        compare(MenuModel.resolve(tree, "root"), "");
        compare(MenuModel.resolve(tree, "nope"), "");
    }

    function test_children_of_root_are_the_roots() {
        const tree = MenuModel.parse(sample);
        const kids = MenuModel.childrenOf(tree, "");
        compare(kids.length, 3);
        compare(kids[0].label, "System");
    }

    function test_breadcrumb() {
        const tree = MenuModel.parse(sample);
        compare(MenuModel.breadcrumb(tree, "system.lock"), ["System", "Lock"]);
        compare(MenuModel.breadcrumb(tree, ""), []);
    }

    function test_leaves_under_is_recursive_and_skips_submenus() {
        const tree = MenuModel.parse(sample);
        const leaves = MenuModel.leavesUnder(tree, "").map(n => n.id);
        compare(leaves, ["system.lock", "system.reboot", "learn.niri"]);
    }

    function test_defaults_are_empty_strings_not_undefined() {
        const tree = MenuModel.parse(sample);
        compare(tree.nodes["learn"].action, "");
        compare(tree.nodes["learn"].when, "");
        compare(tree.nodes["learn"].aliases.length, 0);
    }

    function test_orphan_becomes_a_root_and_is_recorded() {
        const tree = MenuModel.parse('{ "a.b": {"label":"Orphan"} }');
        compare(tree.roots, ["a.b"]);
        compare(tree.orphans, ["a.b"]);
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/Documents/dms-plugins && nix develop -c qmltestrunner -input plugins/dankmenu/tests/tst_menumodel.qml`
Expected: FAIL — the import cannot be resolved because `MenuModel.js` does not exist.

- [ ] **Step 3: Write `MenuModel.js`**

```javascript
.pragma library

// Omarchy's menu files are JSONC: comments and trailing commas, for
// Neovim-friendly editing. Qt has no JSONC reader, so strip to strict JSON
// first. Both strippers are string-aware -- a "//" inside a URL and a comma
// inside a label are data, not syntax.

function stripComments(text) {
    var out = "";
    var i = 0;
    var n = text.length;
    var inString = false;

    while (i < n) {
        var c = text.charAt(i);

        if (inString) {
            out += c;
            if (c === "\\") {
                out += text.charAt(i + 1);
                i += 2;
                continue;
            }
            if (c === '"')
                inString = false;
            i++;
            continue;
        }

        if (c === '"') {
            inString = true;
            out += c;
            i++;
            continue;
        }

        if (c === "/" && text.charAt(i + 1) === "/") {
            while (i < n && text.charAt(i) !== "\n")
                i++;
            continue;
        }

        if (c === "/" && text.charAt(i + 1) === "*") {
            i += 2;
            while (i < n && !(text.charAt(i) === "*" && text.charAt(i + 1) === "/"))
                i++;
            i += 2;
            continue;
        }

        out += c;
        i++;
    }

    return out;
}

function stripTrailingCommas(text) {
    var out = "";
    var i = 0;
    var n = text.length;
    var inString = false;

    while (i < n) {
        var c = text.charAt(i);

        if (inString) {
            out += c;
            if (c === "\\") {
                out += text.charAt(i + 1);
                i += 2;
                continue;
            }
            if (c === '"')
                inString = false;
            i++;
            continue;
        }

        if (c === '"') {
            inString = true;
            out += c;
            i++;
            continue;
        }

        if (c === ",") {
            var j = i + 1;
            while (j < n && " \t\r\n".indexOf(text.charAt(j)) !== -1)
                j++;
            var next = text.charAt(j);
            if (next === "}" || next === "]") {
                i++;
                continue;
            }
        }

        out += c;
        i++;
    }

    return out;
}

function parse(text) {
    return build(JSON.parse(stripTrailingCommas(stripComments(text))));
}

// Dotted ids imply hierarchy: "setup.network.dns" is a child of
// "setup.network". Declaration order in the file is the display order.
function build(obj) {
    var nodes = {};
    var order = [];

    for (var id in obj) {
        var raw = obj[id] || {};
        var dot = id.lastIndexOf(".");
        nodes[id] = {
            id: id,
            parent: dot === -1 ? "" : id.substring(0, dot),
            icon: raw.icon || "",
            iconFont: raw.iconFont || "",
            label: raw.label || id,
            title: raw.title || raw.label || id,
            aliases: raw.aliases || [],
            action: raw.action || "",
            target: raw.target || "",
            provider: raw.provider || "",
            when: raw.when || "",
            checked: raw.checked || "",
            disabled: raw.disabled || "",
            children: []
        };
        order.push(id);
    }

    var roots = [];
    var orphans = [];

    for (var k = 0; k < order.length; k++) {
        var node = nodes[order[k]];
        if (!node.parent) {
            roots.push(node.id);
            continue;
        }
        if (nodes[node.parent]) {
            nodes[node.parent].children.push(node.id);
            continue;
        }
        // A dotted id whose parent was never declared. Surfacing it at the
        // root beats dropping it silently -- a typo in the tree stays visible.
        orphans.push(node.id);
        roots.push(node.id);
    }

    var aliases = {};
    for (var m = 0; m < order.length; m++) {
        var aliasList = nodes[order[m]].aliases;
        for (var a = 0; a < aliasList.length; a++)
            aliases[aliasList[a]] = order[m];
    }

    return { nodes: nodes, roots: roots, aliases: aliases, orphans: orphans };
}

function kindOf(node) {
    if (!node)
        return "submenu";
    if (node.action)
        return "action";
    if (node.target)
        return "link";
    if (node.provider)
        return "provider";
    return "submenu";
}

// "" is the root level. An unresolvable route also lands on the root; the
// caller warns.
function resolve(tree, route) {
    if (!route || route === "root")
        return "";
    if (tree.nodes[route])
        return route;
    if (tree.aliases[route])
        return tree.aliases[route];
    return "";
}

function childrenOf(tree, id) {
    var ids = id ? (tree.nodes[id] ? tree.nodes[id].children : []) : tree.roots;
    var out = [];
    for (var i = 0; i < ids.length; i++)
        out.push(tree.nodes[ids[i]]);
    return out;
}

function breadcrumb(tree, id) {
    var parts = [];
    var cur = id;
    while (cur && tree.nodes[cur]) {
        parts.unshift(tree.nodes[cur].label);
        cur = tree.nodes[cur].parent;
    }
    return parts;
}

// Everything runnable at or below `id`, depth-first in file order. Providers
// are excluded: their contents are generated at open time, not declared here.
function leavesUnder(tree, id) {
    var out = [];

    function walk(nodeId) {
        var kids = childrenOf(tree, nodeId);
        for (var i = 0; i < kids.length; i++) {
            var kind = kindOf(kids[i]);
            if (kind === "action" || kind === "link")
                out.push(kids[i]);
            else if (kind === "submenu")
                walk(kids[i].id);
        }
    }

    walk(id);
    return out;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/Documents/dms-plugins && nix develop -c qmltestrunner -input plugins/dankmenu/tests/tst_menumodel.qml`
Expected: PASS, 14 tests, exit code 0.

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu/MenuModel.js plugins/dankmenu/tests/tst_menumodel.qml
git commit -m "feat(dankmenu): JSONC parsing and menu tree construction

Omarchy's schema verbatim, so subtrees of their menu file paste in and
parse. Both JSONC strippers are string-aware: a // inside a URL and a
comma inside a label are data, not syntax."
```

---

## Task 4: `Search.js` — fuzzy scoring and ranking

**Files:**
- Create: `plugins/dankmenu/Search.js`
- Test: `plugins/dankmenu/tests/tst_search.qml`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `scoreText(query, text) -> number` (`-1` means no match)
  - `scoreEntry(query, entry) -> number` where `entry = { label, comment, aliases }`
  - `rank(query, entries) -> [entry]` — sorted best-first, non-matches removed, ties broken by original order; each returned entry gains `_score`. `entry.boost` (default `0`) is added to a matching entry's score.

- [ ] **Step 1: Write the failing test**

`plugins/dankmenu/tests/tst_search.qml`:

```qml
import QtQuick
import QtTest
import "../Search.js" as Search

TestCase {
    name: "Search"

    function entry(label, comment, aliases, boost) {
        return {
            label: label,
            comment: comment || "",
            aliases: aliases || [],
            boost: boost || 0
        };
    }

    function test_empty_query_matches_everything_with_zero_score() {
        compare(Search.scoreText("", "anything"), 0);
    }

    function test_non_subsequence_does_not_match() {
        compare(Search.scoreText("zzz", "System"), -1);
    }

    function test_subsequence_matches() {
        verify(Search.scoreText("sst", "System Settings") > 0);
    }

    function test_prefix_beats_midword() {
        verify(Search.scoreText("re", "Reboot") > Search.scoreText("re", "Screensaver"));
    }

    function test_contiguous_beats_scattered() {
        verify(Search.scoreText("boot", "Reboot") > Search.scoreText("boot", "Big Orange Octopus Tool"));
    }

    function test_word_boundary_beats_interior() {
        verify(Search.scoreText("dns", "Set DNS") > Search.scoreText("dns", "Sedans"));
    }

    function test_shorter_target_wins_on_equal_match() {
        verify(Search.scoreText("lock", "Lock") > Search.scoreText("lock", "Lock The Screen Right Now"));
    }

    function test_case_insensitive() {
        compare(Search.scoreText("LOCK", "lock"), Search.scoreText("lock", "Lock"));
    }

    function test_label_outranks_comment() {
        const a = Search.scoreEntry("dns", entry("DNS", "network"));
        const b = Search.scoreEntry("dns", entry("Network", "DNS"));
        verify(a > b);
    }

    function test_comment_outranks_alias() {
        const a = Search.scoreEntry("wifi", entry("Network", "wifi settings"));
        const b = Search.scoreEntry("wifi", entry("Network", "", ["wifi"]));
        verify(a > b);
    }

    function test_alias_still_matches_when_label_does_not() {
        verify(Search.scoreEntry("power-menu", entry("System", "", ["power-menu"])) > 0);
    }

    function test_boost_is_added() {
        const plain = Search.scoreEntry("fire", entry("Firefox"));
        const boosted = Search.scoreEntry("fire", entry("Firefox", "", [], 10));
        compare(boosted, plain + 10);
    }

    function test_boost_does_not_rescue_a_non_match() {
        compare(Search.scoreEntry("zzz", entry("Firefox", "", [], 1000)), -1);
    }

    function test_rank_drops_non_matches_and_sorts() {
        const items = [entry("Screensaver"), entry("Reboot"), entry("Lock")];
        const out = Search.rank("re", items);
        compare(out.length, 2);
        compare(out[0].label, "Reboot");
        compare(out[1].label, "Screensaver");
    }

    function test_rank_with_empty_query_preserves_order() {
        const items = [entry("C"), entry("A"), entry("B")];
        const out = Search.rank("", items);
        compare(out.map(e => e.label), ["C", "A", "B"]);
    }

    function test_rank_ties_break_on_original_order() {
        const items = [entry("Lock"), entry("Lock")];
        items[0].id = "first";
        items[1].id = "second";
        const out = Search.rank("lock", items);
        compare(out[0].id, "first");
    }

    function test_rank_sets_score_field() {
        const out = Search.rank("lock", [entry("Lock")]);
        verify(out[0]._score > 0);
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/Documents/dms-plugins && nix develop -c qmltestrunner -input plugins/dankmenu/tests/tst_search.qml`
Expected: FAIL — `Search.js` does not exist.

- [ ] **Step 3: Write `Search.js`**

```javascript
.pragma library

// Written for this plugin. DMS's own launcher scorer lives behind
// AppSearchService/DankLauncherV2 and is not reachable from a plugin, and
// reaching for it would couple the menu to the spotlight it deliberately
// replaces.

var LABEL_WEIGHT = 1.0;
var COMMENT_WEIGHT = 0.6;
var ALIAS_WEIGHT = 0.45;

var BONUS_CONTIGUOUS = 4;
var BONUS_START = 6;
var BONUS_WORD_BOUNDARY = 3;
var BONUS_FULL_PREFIX = 8;
var LENGTH_PENALTY = 0.05;

var BOUNDARY_CHARS = " \t-_./:";

// Subsequence match with position bonuses. Returns -1 when `query`'s
// characters do not appear in order in `text`.
function scoreText(query, text) {
    if (!query)
        return 0;
    if (!text)
        return -1;

    var q = query.toLowerCase();
    var t = text.toLowerCase();

    var score = 0;
    var qi = 0;
    var prev = -2;

    for (var ti = 0; ti < t.length && qi < q.length; ti++) {
        if (t.charAt(ti) !== q.charAt(qi))
            continue;

        var bonus = 1;
        if (prev === ti - 1)
            bonus += BONUS_CONTIGUOUS;
        if (ti === 0)
            bonus += BONUS_START;
        else if (BOUNDARY_CHARS.indexOf(t.charAt(ti - 1)) !== -1)
            bonus += BONUS_WORD_BOUNDARY;

        score += bonus;
        prev = ti;
        qi++;
    }

    if (qi < q.length)
        return -1;

    if (t.indexOf(q) === 0)
        score += BONUS_FULL_PREFIX;

    score -= Math.max(0, t.length - q.length) * LENGTH_PENALTY;
    return score;
}

// Best of label / comment / aliases, weighted so a label hit always outranks
// the same hit in a comment, and a comment hit outranks an alias.
function scoreEntry(query, entry) {
    if (!query)
        return 0;

    var best = -1;

    var labelScore = scoreText(query, entry.label);
    if (labelScore >= 0)
        best = Math.max(best, labelScore * LABEL_WEIGHT);

    var commentScore = scoreText(query, entry.comment || "");
    if (commentScore >= 0)
        best = Math.max(best, commentScore * COMMENT_WEIGHT);

    var aliases = entry.aliases || [];
    for (var i = 0; i < aliases.length; i++) {
        var aliasScore = scoreText(query, aliases[i]);
        if (aliasScore >= 0)
            best = Math.max(best, aliasScore * ALIAS_WEIGHT);
    }

    if (best < 0)
        return -1;

    // Frecency and similar nudges ride on top of a match; they never create
    // one, or a heavily used app would surface for a query it has no letters
    // in common with.
    return best + (entry.boost || 0);
}

function rank(query, entries) {
    var scored = [];

    for (var i = 0; i < entries.length; i++) {
        var s = scoreEntry(query, entries[i]);
        if (s < 0)
            continue;
        entries[i]._score = s;
        scored.push({ index: i, score: s, entry: entries[i] });
    }

    // Decorated sort: Array.prototype.sort's stability is not something to
    // rely on across engines, and an unfiltered level must read in the order
    // the tree declares.
    scored.sort(function (a, b) {
        if (b.score !== a.score)
            return b.score - a.score;
        return a.index - b.index;
    });

    var out = [];
    for (var k = 0; k < scored.length; k++)
        out.push(scored[k].entry);
    return out;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/Documents/dms-plugins && nix develop -c qmltestrunner -input plugins/dankmenu/tests/tst_search.qml`
Expected: PASS, 17 tests, exit code 0.

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu/Search.js plugins/dankmenu/tests/tst_search.qml
git commit -m "feat(dankmenu): fuzzy scorer and ranking

Subsequence gate with contiguity, word-boundary and prefix bonuses;
label beats comment beats alias. Boosts (frecency) add to a match but
never create one. Decorated sort so ties keep tree order."
```

---

## Task 5: `Conditions.js` — batched condition script and output parsing

**Files:**
- Create: `plugins/dankmenu/Conditions.js`
- Test: `plugins/dankmenu/tests/tst_conditions.qml`

**Interfaces:**
- Consumes: `MenuModel.js` node shape (`when` / `checked` / `disabled` strings).
- Produces:
  - `collect(nodes) -> [{ id, kind, snippet }]` for `kind` in `"when" | "checked" | "disabled"`
  - `shellQuote(s) -> string`
  - `buildScript(conds) -> string`
  - `parseOutput(text) -> { id: { when: rc, checked: rc, disabled: rc } }`
  - `applyTo(node, results) -> { visible, checked, disabled }`

- [ ] **Step 1: Write the failing test**

`plugins/dankmenu/tests/tst_conditions.qml`:

```qml
import QtQuick
import QtTest
import "../Conditions.js" as Conditions

TestCase {
    name: "Conditions"

    function node(id, when, checked, disabled) {
        return {
            id: id,
            when: when || "",
            checked: checked || "",
            disabled: disabled || ""
        };
    }

    function test_collect_skips_nodes_without_conditions() {
        const out = Conditions.collect([node("a"), node("b", "true")]);
        compare(out.length, 1);
        compare(out[0].id, "b");
        compare(out[0].kind, "when");
    }

    function test_collect_returns_all_three_kinds_in_order() {
        const out = Conditions.collect([node("a", "w", "c", "d")]);
        compare(out.map(c => c.kind), ["when", "checked", "disabled"]);
    }

    function test_shell_quote_wraps_and_escapes() {
        compare(Conditions.shellQuote("plain"), "'plain'");
        compare(Conditions.shellQuote("it's"), "'it'\\''s'");
    }

    function test_build_script_redirects_snippet_output_only() {
        const script = Conditions.buildScript([{ id: "a", kind: "when", snippet: "grep -q x /etc/f" }]);
        compare(script, "{ grep -q x /etc/f ; } >/dev/null 2>&1; printf '%s\\t%s\\t%s\\n' 'a' 'when' \"$?\"");
    }

    function test_build_script_one_line_per_condition() {
        const script = Conditions.buildScript([
            { id: "a", kind: "when", snippet: "true" },
            { id: "b", kind: "checked", snippet: "false" }
        ]);
        compare(script.split("\n").length, 2);
    }

    function test_build_script_empty_is_empty_string() {
        compare(Conditions.buildScript([]), "");
    }

    function test_parse_output() {
        const results = Conditions.parseOutput("a\twhen\t0\nb\tchecked\t1\n");
        compare(results["a"].when, 0);
        compare(results["b"].checked, 1);
    }

    function test_parse_output_ignores_junk_lines() {
        const results = Conditions.parseOutput("noise\na\twhen\t0\n\n");
        compare(Object.keys(results).length, 1);
        compare(results["a"].when, 0);
    }

    function test_apply_no_conditions_is_visible_unchecked_enabled() {
        const state = Conditions.applyTo(node("a"), {});
        compare(state.visible, true);
        compare(state.checked, false);
        compare(state.disabled, false);
    }

    function test_apply_when_failing_hides_row() {
        const state = Conditions.applyTo(node("a", "cmd"), { a: { when: 1 } });
        compare(state.visible, false);
    }

    function test_apply_when_succeeding_shows_row() {
        const state = Conditions.applyTo(node("a", "cmd"), { a: { when: 0 } });
        compare(state.visible, true);
    }

    function test_apply_checked_and_disabled() {
        const state = Conditions.applyTo(node("a", "", "cmd", "cmd2"), { a: { checked: 0, disabled: 0 } });
        compare(state.checked, true);
        compare(state.disabled, true);
    }

    function test_pending_result_keeps_row_visible() {
        // Results have not arrived yet: a row with a `when` must not flicker
        // out of the list and back in.
        const state = Conditions.applyTo(node("a", "cmd"), {});
        compare(state.visible, true);
        compare(state.pending, true);
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/Documents/dms-plugins && nix develop -c qmltestrunner -input plugins/dankmenu/tests/tst_conditions.qml`
Expected: FAIL — `Conditions.js` does not exist.

- [ ] **Step 3: Write `Conditions.js`**

```javascript
.pragma library

var KINDS = ["when", "checked", "disabled"];

function collect(nodes) {
    var out = [];
    for (var i = 0; i < nodes.length; i++) {
        for (var k = 0; k < KINDS.length; k++) {
            var kind = KINDS[k];
            var snippet = nodes[i][kind];
            if (snippet)
                out.push({ id: nodes[i].id, kind: kind, snippet: snippet });
        }
    }
    return out;
}

function shellQuote(s) {
    return "'" + String(s).split("'").join("'\\''") + "'";
}

// One script per menu level, not one process per row: a level with a dozen
// conditioned rows would otherwise mean a dozen spawns every time it opens.
// The braces group the snippet so its own stdout/stderr are discarded while
// the printf that reports its status still reaches us.
function buildScript(conds) {
    var lines = [];
    for (var i = 0; i < conds.length; i++) {
        var c = conds[i];
        lines.push("{ " + c.snippet + " ; } >/dev/null 2>&1; printf '%s\\t%s\\t%s\\n' "
                   + shellQuote(c.id) + " " + shellQuote(c.kind) + " \"$?\"");
    }
    return lines.join("\n");
}

function parseOutput(text) {
    var results = {};
    var lines = String(text).split("\n");

    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].split("\t");
        if (parts.length !== 3)
            continue;
        var id = parts[0];
        if (!results[id])
            results[id] = {};
        results[id][parts[1]] = parseInt(parts[2], 10);
    }

    return results;
}

// Omarchy's semantics: `when` hides unless it succeeds, `checked` ticks when
// it succeeds, `disabled` dims, ticks and blocks selection when it succeeds.
// Until results land, rows stay visible and unadorned -- a row that vanished
// and reappeared would be worse than one that settles a frame late.
function applyTo(node, results) {
    var r = results[node.id] || {};
    var pending = false;

    var visible = true;
    if (node.when) {
        if (r.when === undefined)
            pending = true;
        else
            visible = r.when === 0;
    }

    var checked = false;
    if (node.checked) {
        if (r.checked === undefined)
            pending = true;
        else
            checked = r.checked === 0;
    }

    var disabled = false;
    if (node.disabled) {
        if (r.disabled === undefined)
            pending = true;
        else
            disabled = r.disabled === 0;
    }

    return { visible: visible, checked: checked, disabled: disabled, pending: pending };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/Documents/dms-plugins && nix develop -c qmltestrunner -input plugins/dankmenu/tests/tst_conditions.qml`
Expected: PASS, 13 tests, exit code 0.

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu/Conditions.js plugins/dankmenu/tests/tst_conditions.qml
git commit -m "feat(dankmenu): batched when/checked/disabled evaluation

One generated script per menu level rather than one process per row.
Rows stay visible while results are pending so nothing flickers out of
the list and back in."
```

---

## Task 6: Menu list and keyboard navigation

**Files:**
- Create: `plugins/dankmenu/MenuList.qml`
- Modify: `plugins/dankmenu/MenuWindow.qml` (replace the empty card)
- Modify: `plugins/dankmenu/DankMenuDaemon.qml` (load a tree, pass it down)

**Interfaces:**
- Consumes: `MenuModel.js` (`parse`, `resolve`, `childrenOf`, `breadcrumb`, `kindOf`).
- Produces: `MenuWindow` gains `property var tree`, `property string currentId`, `function enter(id)`, `function pop()`. `MenuList` exposes `property var rows`, `property int currentIndex`, `signal activated(var row)`.

- [ ] **Step 1: Write `MenuList.qml`**

```qml
import QtQuick
import qs.Common
import qs.Widgets

ListView {
    id: root

    // rows: [{ id, label, icon, kind, comment, checked, disabled }]
    property var rows: []

    signal activated(var row)

    model: rows
    clip: true
    currentIndex: 0
    highlightMoveDuration: Theme.shortDuration
    keyNavigationEnabled: false   // the window owns key handling

    delegate: Rectangle {
        required property int index
        required property var modelData

        width: ListView.view.width
        height: 44
        radius: Theme.cornerRadius
        color: index === root.currentIndex ? Theme.primary : "transparent"
        opacity: modelData.disabled ? 0.45 : 1

        MouseArea {
            anchors.fill: parent
            enabled: !modelData.disabled
            onClicked: {
                root.currentIndex = index;
                root.activated(modelData);
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingM

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: modelData.icon !== ""
                name: modelData.icon
                size: Theme.fontSizeLarge
                color: index === root.currentIndex ? Theme.surface : Theme.surfaceText
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.spacingXL * 3

                StyledText {
                    text: modelData.label + (modelData.checked ? "  ✓" : "")
                    color: index === root.currentIndex ? Theme.surface : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    elide: Text.ElideRight
                    width: parent.width
                }

                StyledText {
                    visible: modelData.comment !== ""
                    text: modelData.comment
                    color: index === root.currentIndex ? Theme.surface : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        // A submenu advertises that Enter goes deeper rather than doing
        // something irreversible.
        DankIcon {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            visible: modelData.kind === "submenu" || modelData.kind === "provider"
            name: "chevron_right"
            size: Theme.fontSizeMedium
            color: index === root.currentIndex ? Theme.surface : Theme.surfaceVariantText
        }
    }
}
```

- [ ] **Step 2: Rewrite `MenuWindow.qml` around the list**

Replace the file written in Task 2 with:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import "MenuModel.js" as MenuModel

PanelWindow {
    id: root

    property var tree: ({ nodes: {}, roots: [], aliases: {}, orphans: [] })
    property bool menuVisible: false
    property string currentId: ""
    property string query: ""

    signal closed

    readonly property var breadcrumb: MenuModel.breadcrumb(tree, currentId)
    readonly property string headerTitle: currentId && tree.nodes[currentId]
        ? tree.nodes[currentId].title : "Menu"

    function rowsFor(id) {
        const kids = MenuModel.childrenOf(tree, id);
        const out = [];
        for (let i = 0; i < kids.length; i++) {
            out.push({
                id: kids[i].id,
                label: kids[i].label,
                icon: kids[i].icon,
                comment: "",
                kind: MenuModel.kindOf(kids[i]),
                checked: false,
                disabled: false
            });
        }
        return out;
    }

    function openAt(route) {
        currentId = MenuModel.resolve(tree, route);
        query = "";
        list.rows = rowsFor(currentId);
        list.currentIndex = 0;
        menuVisible = true;
    }

    function closeMenu() {
        menuVisible = false;
        closed();
    }

    function enter(row) {
        if (!row || row.disabled)
            return;
        if (row.kind === "submenu" || row.kind === "provider") {
            currentId = row.id;
            query = "";
            list.rows = rowsFor(currentId);
            list.currentIndex = 0;
            return;
        }
        // Leaves execute in Task 8.
        closeMenu();
    }

    // Escape and Left pop a level; at the root they close. The query belongs
    // to the level, not the session, so it clears on every move.
    function pop() {
        if (!currentId) {
            closeMenu();
            return;
        }
        const parent = tree.nodes[currentId] ? tree.nodes[currentId].parent : "";
        currentId = parent;
        query = "";
        list.rows = rowsFor(currentId);
        list.currentIndex = 0;
    }

    visible: menuVisible
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "dms:plugins:dankMenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: menuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeMenu()
        }
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: root.menuVisible

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                root.pop();
                event.accepted = true;
                break;
            case Qt.Key_Left:
                root.pop();
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Right:
                root.enter(list.rows[list.currentIndex]);
                event.accepted = true;
                break;
            case Qt.Key_Down:
                list.currentIndex = Math.min(list.currentIndex + 1, list.rows.length - 1);
                event.accepted = true;
                break;
            case Qt.Key_Up:
                list.currentIndex = Math.max(list.currentIndex - 1, 0);
                event.accepted = true;
                break;
            case Qt.Key_N:
                if (event.modifiers & Qt.ControlModifier) {
                    list.currentIndex = Math.min(list.currentIndex + 1, list.rows.length - 1);
                    event.accepted = true;
                }
                break;
            case Qt.Key_P:
                if (event.modifiers & Qt.ControlModifier) {
                    list.currentIndex = Math.max(list.currentIndex - 1, 0);
                    event.accepted = true;
                }
                break;
            case Qt.Key_Backspace:
                if (root.query === "") {
                    root.pop();
                    event.accepted = true;
                }
                break;
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(720, parent.width - Theme.spacingXL * 2)
            height: Math.min(520, parent.height - Theme.spacingXL * 2)
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outline

            MouseArea {
                anchors.fill: parent
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                StyledText {
                    width: parent.width
                    text: root.breadcrumb.length ? root.breadcrumb.join("  ›  ") : "Menu"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideLeft
                }

                StyledText {
                    width: parent.width
                    text: root.headerTitle
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                }

                MenuList {
                    id: list
                    width: parent.width
                    height: parent.height - y
                    onActivated: row => root.enter(row)
                }
            }
        }
    }
}
```

The search field arrives in Task 7; `query` is already threaded through so
Backspace-pops behaves correctly from the start.

- [ ] **Step 3: Give the daemon a tree to pass down**

In `DankMenuDaemon.qml`, add the import and a hardcoded probe tree (replaced by
the real file in Task 11):

```qml
import "MenuModel.js" as MenuModel
```

and inside `PluginComponent`:

```qml
    // Task 11 replaces this with the bundled menu.jsonc / menuPath override.
    readonly property var tree: MenuModel.parse('{'
        + '"style": {"icon":"palette","label":"Style"},'
        + '"style.theme": {"icon":"colorize","label":"Theme"},'
        + '"system": {"icon":"power_settings_new","label":"System","aliases":["power-menu"]},'
        + '"system.lock": {"icon":"lock","label":"Lock","action":"loginctl lock-session"},'
        + '"system.reboot": {"icon":"restart_alt","label":"Reboot","action":"systemctl reboot"}'
        + '}')
```

and set it on the loaded window:

```qml
        component: MenuWindow {
            tree: root.tree
            onClosed: windowLoader.loading = false
        }
```

- [ ] **Step 4: Verify navigation in the live shell**

```bash
dms ipc call plugins reload dankMenu
dms ipc call dankMenu open root
```

Expected, by hand:
- Root shows `Style` and `System`, both with a chevron.
- `Down` then `Enter` enters `System`; the header reads `System` and the breadcrumb `System`.
- `Escape` returns to the root; `Escape` again closes.
- `dms ipc call dankMenu open power-menu` opens directly inside `System` — alias resolution working.

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu/MenuList.qml plugins/dankmenu/MenuWindow.qml plugins/dankmenu/DankMenuDaemon.qml
git commit -m "feat(dankmenu): hierarchical list with keyboard navigation

Enter/Right descends, Escape/Left pops, Escape at root closes. The
query clears on every level change: it describes the level, not the
session."
```

---

## Task 7: Search inside the menu

**Files:**
- Modify: `plugins/dankmenu/MenuWindow.qml`

**Interfaces:**
- Consumes: `Search.js` (`rank`), `MenuModel.js` (`leavesUnder`, `breadcrumb`).
- Produces: `MenuWindow.rowsFor(id, query)` — with a non-empty query, returns ranked *leaves of the whole subtree* with breadcrumb comments; with an empty query, the level's direct children.

- [ ] **Step 1: Add the search field**

In `MenuWindow.qml`, between the title and the list:

```qml
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        clip: true
                        focus: root.menuVisible
                        onTextChanged: root.query = text

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            text: "Search"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                        }
                    }
                }
```

- [ ] **Step 2: Make the rows query-aware**

Replace `rowsFor` with:

```qml
    // Empty query: this level's children, in tree order. Non-empty: every
    // runnable leaf at or below this level, ranked, each captioned with where
    // it lives. That makes the root a command palette without a separate mode.
    function rowsFor(id, q) {
        if (!q) {
            const kids = MenuModel.childrenOf(tree, id);
            const out = [];
            for (let i = 0; i < kids.length; i++) {
                out.push({
                    id: kids[i].id,
                    label: kids[i].label,
                    icon: kids[i].icon,
                    comment: "",
                    kind: MenuModel.kindOf(kids[i]),
                    checked: false,
                    disabled: false
                });
            }
            return out;
        }

        const leaves = MenuModel.leavesUnder(tree, id);
        const entries = [];
        for (let i = 0; i < leaves.length; i++) {
            const crumbs = MenuModel.breadcrumb(tree, leaves[i].parent);
            entries.push({
                id: leaves[i].id,
                label: leaves[i].label,
                icon: leaves[i].icon,
                comment: crumbs.join("  ›  "),
                kind: MenuModel.kindOf(leaves[i]),
                aliases: leaves[i].aliases,
                checked: false,
                disabled: false
            });
        }
        return Search.rank(q, entries);
    }
```

Add the import at the top:

```qml
import "Search.js" as Search
```

- [ ] **Step 3: Recompute rows whenever the query changes**

Add to `MenuWindow.qml`:

```qml
    onQueryChanged: {
        list.rows = rowsFor(currentId, query);
        list.currentIndex = 0;
    }
```

and update the three existing `list.rows = rowsFor(currentId)` call sites in
`openAt`, `enter` and `pop` to `rowsFor(currentId, "")`, and clear the field by
setting `searchInput.text = ""` alongside each `query = ""`.

- [ ] **Step 4: Verify in the live shell**

```bash
dms ipc call plugins reload dankMenu
dms ipc call dankMenu open root
```

Expected, by hand:
- Typing `re` at the root surfaces `Reboot` with the caption `System`, even though `Reboot` is a level down.
- `Backspace` on the now-empty field pops or closes rather than doing nothing.
- Entering `System` and typing `lo` shows only `Lock`.

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu/MenuWindow.qml
git commit -m "feat(dankmenu): recursive subtree search with breadcrumb captions

A query searches every leaf at or below the current level, so the root
is a command palette and a submenu is a scoped one -- no separate
search-everything mode."
```

---

## Task 8: Executing actions and links

**Files:**
- Modify: `plugins/dankmenu/MenuWindow.qml`

**Interfaces:**
- Produces: `MenuWindow.run(node)` — executes an action or opens a link, then closes.

- [ ] **Step 1: Add the process runner**

In `MenuWindow.qml`, add `import Quickshell.Io` and:

```qml
    Component {
        id: actionProcess

        Process {
            property string script: ""

            // bash -lc, not a bare exec: menu actions are shell text. Omarchy's
            // use pipes, $(...), && and quoting freely, and the schema
            // compatibility this plugin keeps is only real if that still works.
            command: ["bash", "-lc", script]

            onExited: exitCode => {
                if (exitCode !== 0)
                    console.warn("dankMenu: action exited", exitCode, "-", script);
                destroy();
            }
        }
    }

    function run(row) {
        const node = tree.nodes[row.id];
        if (!node)
            return;

        if (node.action) {
            const proc = actionProcess.createObject(root, { script: node.action });
            proc.running = true;
        } else if (node.target) {
            Qt.openUrlExternally(node.target);
        }

        closeMenu();
    }
```

- [ ] **Step 2: Call it from `enter`**

Replace the `// Leaves execute in Task 8.` branch:

```qml
        run(row);
```

- [ ] **Step 3: Verify in the live shell**

```bash
dms ipc call plugins reload dankMenu
```

Expected, by hand: open the menu, enter `System`, select `Lock`, press Enter — the session locks and the menu is gone. Add a temporary link row to the probe tree and confirm it opens in the browser, then remove it.

For a non-destructive check of the shell semantics, temporarily set the probe
tree's `system.lock` action to `notify-send dankMenu "$(date +%H:%M)"` and
confirm the notification carries a real time — proving command substitution
survives the trip.

- [ ] **Step 4: Commit**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu/MenuWindow.qml
git commit -m "feat(dankmenu): run actions and open links

Actions go through bash -lc because menu actions are shell text, not
argv: pipes, command substitution and && all have to survive."
```

---

## Task 9: Wire conditions into the list

**Files:**
- Create: `plugins/dankmenu/Conditions.qml`
- Modify: `plugins/dankmenu/MenuWindow.qml`

**Interfaces:**
- Consumes: `Conditions.js` (`collect`, `buildScript`, `parseOutput`, `applyTo`).
- Produces: `Conditions.qml` exposes `property var results`, `function evaluate(nodes)`, `function clear()`, `signal settled()`.

- [ ] **Step 1: Write `Conditions.qml`**

```qml
import QtQuick
import Quickshell.Io
import "Conditions.js" as ConditionsJs

Item {
    id: root

    // { id: { when: rc, checked: rc, disabled: rc } }
    property var results: ({})

    signal settled

    function clear() {
        results = {};
    }

    function evaluate(nodes) {
        const conds = ConditionsJs.collect(nodes);
        if (conds.length === 0) {
            results = {};
            settled();
            return;
        }
        proc.script = ConditionsJs.buildScript(conds);
        proc.running = true;
    }

    Process {
        id: proc

        property string script: ""

        command: ["bash", "-lc", script]

        stdout: StdioCollector {
            onStreamFinished: {
                root.results = ConditionsJs.parseOutput(text);
                root.settled();
            }
        }
    }
}
```

- [ ] **Step 2: Use it from `MenuWindow.qml`**

Add the instance:

```qml
    Conditions {
        id: conditions
        onSettled: {
            list.rows = root.rowsFor(root.currentId, root.query);
        }
    }
```

Add a helper that evaluates the nodes a level can show — for a query, that is
the whole subtree's leaves, so conditioned rows stay correct in search results:

```qml
    function evaluateConditions() {
        const nodes = query
            ? MenuModel.leavesUnder(tree, currentId)
            : MenuModel.childrenOf(tree, currentId);
        conditions.clear();
        conditions.evaluate(nodes);
    }
```

Call `evaluateConditions()` at the end of `openAt`, `enter` (submenu branch)
and `pop`, and in `onQueryChanged`.

- [ ] **Step 3: Apply the results when building rows**

In `rowsFor`, replace the hardcoded `checked: false, disabled: false` in both
branches with a state lookup, and drop invisible rows:

```qml
        const state = ConditionsJs.applyTo(node, conditions.results);
        if (!state.visible)
            continue;
        // ... checked: state.checked, disabled: state.disabled
```

Add `import "Conditions.js" as ConditionsJs` at the top. In the query branch,
`node` is `leaves[i]`; in the empty-query branch it is `kids[i]`. Because
`applyTo` returns `visible: true` while a result is pending, a slow condition
delays the tick, never the row.

- [ ] **Step 4: Verify in the live shell**

Extend the probe tree with three rows:

```
"system.laptop": {"label":"Laptop only","when":"false","action":"true"},
"system.always": {"label":"Always","when":"true","action":"true"},
"system.ticked": {"label":"Ticked","checked":"true","action":"true"}
```

```bash
dms ipc call plugins reload dankMenu
dms ipc call dankMenu open system
```

Expected: `Always` and `Ticked` are listed, `Laptop only` is not, and `Ticked`
shows `✓`. Then confirm the batching:

```bash
journalctl --user -u dms -n 20 | grep -c dankMenu   # no error lines
```

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu/Conditions.qml plugins/dankmenu/MenuWindow.qml
git commit -m "feat(dankmenu): evaluate row conditions per level

One script per level covers every when/checked/disabled it can show,
including the whole subtree while a search is active."
```

---

## Task 10: Apps — the built-in desktop-entry source

**Files:**
- Create: `plugins/dankmenu/AppSource.qml`
- Modify: `plugins/dankmenu/MenuWindow.qml`

**Interfaces:**
- Consumes: `DesktopEntries` (Quickshell), `SessionService.launchDesktopEntry`, `AppUsageHistoryData.addAppUsage`, `Search.js`.
- Produces: `AppSource.qml` exposes `function entries() -> [row]` and `function launch(row)`. Rows carry `kind: "app"` and an `appId`.

- [ ] **Step 1: Write `AppSource.qml`**

```qml
import QtQuick
import Quickshell
import qs.Common
import qs.Services

// The plugin's own app list. DMS's launcher search is not reachable from a
// plugin and reaching for it would couple this menu to the spotlight it
// replaces -- so the listing, captions and ranking are local. The one thing
// that is *not* reimplemented is launching: SessionService knows about uwsm
// and systemd scopes, and getting that wrong silently breaks process
// accounting for every app started from here.
Item {
    id: root

    // Frecency nudges an app up a match; Search.js adds it only to entries
    // that already matched.
    function boostFor(entry) {
        const usage = AppUsageHistoryData.appUsageRanking || {};
        const record = usage[entry.id] || usage[entry.execString] || null;
        if (!record)
            return 0;
        return Math.min(12, Math.log(1 + (record.usageCount || 0)) * 4);
    }

    function entries() {
        const apps = DesktopEntries.applications.values;
        const out = [];
        for (let i = 0; i < apps.length; i++) {
            const app = apps[i];
            if (app.noDisplay)
                continue;
            out.push({
                id: "app:" + app.id,
                appId: app.id,
                label: app.name,
                icon: app.icon || "application-x-executable",
                comment: app.genericName || app.comment || "Apps",
                kind: "app",
                aliases: app.keywords || [],
                checked: false,
                disabled: false,
                boost: boostFor(app)
            });
        }
        return out;
    }

    function launch(row) {
        const apps = DesktopEntries.applications.values;
        for (let i = 0; i < apps.length; i++) {
            if (apps[i].id !== row.appId)
                continue;
            SessionService.launchDesktopEntry(apps[i]);
            AppUsageHistoryData.addAppUsage(apps[i]);
            return;
        }
        console.warn("dankMenu: no desktop entry for", row.appId);
    }
}
```

- [ ] **Step 2: Show apps under a `provider: "apps"` node**

In `MenuWindow.qml`, add `AppSource { id: appSource }` and, in `rowsFor`'s
empty-query branch, return the app list when the current node is the apps
provider:

```qml
        if (id && tree.nodes[id] && tree.nodes[id].provider === "apps")
            return Search.rank("", appSource.entries());
```

and in the query branch, before ranking:

```qml
        if (id && tree.nodes[id] && tree.nodes[id].provider === "apps")
            return Search.rank(q, appSource.entries());
```

- [ ] **Step 3: Fold apps into root-level search**

Still in the query branch, after the menu entries are collected and only when
`id` is the root:

```qml
        // At the root a query reaches apps too, so one keystroke sequence finds
        // either a command or a program. Inside a submenu it does not: the
        // level is the scope.
        if (!id)
            entries.push.apply(entries, appSource.entries());
```

- [ ] **Step 4: Route activation for app rows**

In `run(row)`, before the `tree.nodes` lookup:

```qml
        if (row.kind === "app") {
            appSource.launch(row);
            closeMenu();
            return;
        }
```

- [ ] **Step 5: Add an apps node to the probe tree**

In `DankMenuDaemon.qml`'s probe tree, add:

```
'"apps": {"icon":"apps","label":"Apps","aliases":["app","applications"],"provider":"apps"},'
```

- [ ] **Step 6: Verify in the live shell**

```bash
dms ipc call plugins reload dankMenu
dms ipc call dankMenu open apps
```

Expected: the installed applications are listed; Enter launches the selected
one and closes the menu. Then `dms ipc call dankMenu open root`, type a program
name, and confirm it appears alongside menu commands. Confirm a launched app
lands in its own scope:

```bash
systemd-cgls --user-unit app.slice | head -20
```

- [ ] **Step 7: Commit**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu/AppSource.qml plugins/dankmenu/MenuWindow.qml plugins/dankmenu/DankMenuDaemon.qml
git commit -m "feat(dankmenu): built-in app list and root-level app search

Listing, captions and ranking are the plugin's own. Only launching
reuses SessionService, which knows about uwsm and systemd scopes --
reimplementing that would silently break process accounting."
```

---

## Task 11: Real tree loading, `menuPath` override, settings, and `refresh`

**Files:**
- Create: `plugins/dankmenu/menu.jsonc`
- Create: `plugins/dankmenu/DankMenuSettings.qml`
- Modify: `plugins/dankmenu/DankMenuDaemon.qml`

**Interfaces:**
- Consumes: `pluginData.menuPath`, `pluginService.savePluginData`.
- Produces: `DankMenuDaemon.tree` parsed from the live file; `refresh()` reloads it.

- [ ] **Step 1: Write the default tree**

`plugins/dankmenu/menu.jsonc` — Omarchy's spine, niri and NixOS underneath.
`install` and `remove` are absent on purpose: adding a package means editing
the flake, which `setup.config` opens.

```jsonc
{
  // dankMenu default tree. Omarchy's schema: object keys are dotted ids,
  // hierarchy is implied by the dots, kind is inferred from the fields.
  // Anything referencing this machine's flake path is overridden from Nix --
  // see modules/desktop/dms/plugins.nix in sitolamix.

  // Root
  "apps": {"icon":"apps","label":"Apps","aliases":["app","applications"],"provider":"apps"},
  "learn": {"icon":"school","label":"Learn"},
  "trigger": {"icon":"bolt","label":"Trigger"},
  "style": {"icon":"palette","label":"Style"},
  "setup": {"icon":"settings","label":"Setup","aliases":["settings"]},
  "update": {"icon":"sync","label":"Update"},
  "system": {"icon":"power_settings_new","label":"System","aliases":["power-menu"]},

  // Learn
  "learn.keybinds": {"icon":"keyboard","label":"Keybinds","action":"dms ipc call keybinds toggleBinds"},
  "learn.niri": {"icon":"grid_view","label":"Niri","target":"https://github.com/YaLTeR/niri/wiki"},
  "learn.nixos": {"icon":"menu_book","label":"NixOS Manual","target":"https://nixos.org/manual/nixos/stable/"},
  "learn.home-manager": {"icon":"home","label":"Home Manager Options","target":"https://nix-community.github.io/home-manager/options.xhtml"},
  "learn.packages": {"icon":"search","label":"Search Packages","target":"https://search.nixos.org/packages"},

  // Trigger
  "trigger.capture": {"icon":"screenshot_region","label":"Capture","aliases":["screenshot","screenrecord"],"action":"dms ipc call screenCaptureToolbar toggle"},
  "trigger.clipboard": {"icon":"content_paste","label":"Clipboard","aliases":["clip"],"action":"dms ipc call clipboard toggle"},
  "trigger.notepad": {"icon":"edit_note","label":"Notepad","action":"dms ipc call notepad toggle"},
  "trigger.emoji": {"icon":"mood","label":"Emoji","aliases":["emoji","emojis"],"action":"dms ipc call spotlight toggleQuery ':e '"},
  "trigger.toggle": {"icon":"toggle_on","label":"Toggle","aliases":["toggle","toggles"]},
  "trigger.toggle.idle": {"icon":"coffee","label":"Stay Awake","action":"dms ipc call inhibit toggle"},
  "trigger.toggle.dnd": {"icon":"notifications_off","label":"Do Not Disturb","action":"dms ipc call notifs toggleDnd"},
  "trigger.toggle.night": {"icon":"nightlight","label":"Night Mode","action":"dms ipc call night toggle"},

  // Style
  "style.theme": {"icon":"colorize","label":"Theme","aliases":["theme","themes"],"action":"dms ipc call settings open"},
  "style.wallpaper": {"icon":"wallpaper","label":"Wallpaper","aliases":["background"],"action":"dms ipc call wallpaper browse"},

  // Setup
  "setup.outputs": {"icon":"monitor","label":"Monitors","action":"niri msg outputs"},
  "setup.network": {"icon":"wifi","label":"Network","aliases":["wifi"],"action":"dms ipc call control-center toggle"},
  "setup.audio": {"icon":"volume_up","label":"Audio","action":"dms ipc call control-center toggle"},

  // System
  "system.lock": {"icon":"lock","label":"Lock","action":"loginctl lock-session"},
  "system.suspend": {"icon":"bedtime","label":"Suspend","action":"systemctl suspend"},
  "system.logout": {"icon":"logout","label":"Logout","action":"niri msg action quit --skip-confirmation"},
  "system.reboot": {"icon":"restart_alt","label":"Reboot","action":"systemctl reboot"},
  "system.shutdown": {"icon":"power_settings_new","label":"Shutdown","action":"systemctl poweroff"},
}
```

Every `dms ipc call` above must be checked against `dms ipc show` on this
machine before the row ships; where a verb does not exist, drop the row rather
than shipping one that fails silently.

- [ ] **Step 2: Verify every action in the default tree actually resolves**

```bash
dms ipc show 2>&1 | head -60
for verb in "keybinds toggleBinds" "clipboard toggle" "notepad toggle" \
            "screenCaptureToolbar toggle" "control-center toggle"; do
  echo "== $verb"; dms ipc call $verb; done
niri msg outputs >/dev/null && echo "niri msg ok"
```

Expected: each prints a success string. Any that errors gets removed from
`menu.jsonc` in this step, not left to fail at runtime.

- [ ] **Step 3: Load the file in the daemon**

Replace the probe tree in `DankMenuDaemon.qml` with a `FileView`:

```qml
    // "" means the bundled tree. A Nix-managed config points this at a
    // generated file; a hand install leaves it alone and gets the default.
    readonly property string menuPath: pluginData.menuPath || ""

    property var tree: ({ nodes: {}, roots: [], aliases: {}, orphans: [] })

    FileView {
        id: menuFile
        path: root.menuPath !== "" ? root.menuPath : Qt.resolvedUrl("menu.jsonc").toString().replace("file://", "")
        watchChanges: true

        onFileChanged: reload()

        onLoaded: {
            try {
                root.tree = MenuModel.parse(text());
                if (root.tree.orphans.length > 0)
                    console.warn("dankMenu: orphaned ids in menu file:", root.tree.orphans.join(", "));
            } catch (e) {
                console.warn("dankMenu: cannot parse menu file", path, "-", e);
            }
        }

        onLoadFailed: console.warn("dankMenu: cannot read menu file", path)
    }
```

and make `refresh()` real:

```qml
        function refresh(): string {
            menuFile.reload();
            return "DANKMENU_REFRESHED";
        }
```

- [ ] **Step 4: Write the settings component**

`plugins/dankmenu/DankMenuSettings.qml`:

```qml
import QtQuick
import qs.Common
import qs.Widgets

FocusScope {
    id: root

    property var pluginService: null

    function save(key, value) {
        if (pluginService)
            pluginService.savePluginData("dankMenu", key, value);
    }

    function load(key, fallback) {
        return pluginService ? pluginService.loadPluginData("dankMenu", key, fallback) : fallback;
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingM

        StyledText {
            text: "Menu file"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
        }

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Absolute path to a JSONC menu tree. Leave empty to use the "
                + "tree bundled with the plugin. On NixOS this is set from "
                + "your configuration and editing it here will not stick."
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }

        Rectangle {
            width: parent.width
            height: 36
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            TextInput {
                id: pathInput
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                text: root.load("menuPath", "")
                onEditingFinished: root.save("menuPath", text)
            }
        }
    }
}
```

- [ ] **Step 5: Verify override and reload**

```bash
cp ~/Documents/dms-plugins/plugins/dankmenu/menu.jsonc /tmp/mymenu.jsonc
sed -i 's/"label":"Learn"/"label":"LEARN OVERRIDE"/' /tmp/mymenu.jsonc
# set menuPath to /tmp/mymenu.jsonc in the DMS plugin settings pane, then:
dms ipc call dankMenu open root
```

Expected: the root shows `LEARN OVERRIDE`. Then edit `/tmp/mymenu.jsonc` again
while the shell runs and confirm the change appears without a restart —
`watchChanges` doing its job. Finally `dms ipc call dankMenu refresh` and
confirm it returns `DANKMENU_REFRESHED`.

- [ ] **Step 6: Commit**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu/menu.jsonc plugins/dankmenu/DankMenuSettings.qml plugins/dankmenu/DankMenuDaemon.qml
git commit -m "feat(dankmenu): load the tree from a file, overridable by path

Bundled menu.jsonc keeps the plugin useful on its own; menuPath lets a
Nix config generate the tree instead. The file is watched, so editing
the tree does not need a shell restart."
```

---

## Task 12: Plugin README and repo-level test wiring

**Files:**
- Create: `plugins/dankmenu/README.md`
- Modify: `~/Documents/dms-plugins/flake.nix` (checks)

**Interfaces:**
- Produces: `nix flake check` running all three dankMenu QML suites and MouthGuard's pytest.

- [ ] **Step 1: Write the plugin README**

`plugins/dankmenu/README.md`:

```markdown
# dankMenu

An [Omarchy](https://github.com/basecamp/omarchy)-style root menu for
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell): one key
to every command on the machine, with drill-in navigation and its own search.

## What it is

Omarchy binds `SUPER+SPACE` to a hierarchical, fuzzy-searchable menu covering
apps, settings, toggles and power actions. This is that menu, as a DMS plugin.

It is a `daemon` plugin owning its own layershell window rather than a
launcher plugin living inside DMS's spotlight — the spotlight modal hides
itself on every item execution with no hook to prevent it, which makes
drill-in navigation impossible there. The search, the ranking and the app
list are the plugin's own code; the only thing borrowed from the shell is
`SessionService.launchDesktopEntry`, so apps land in the right systemd scope.

## Usage

    dms ipc call dankMenu toggle          # open at the root, or close
    dms ipc call dankMenu open system     # open straight into a submenu
    dms ipc call dankMenu open power-menu # aliases work too
    dms ipc call dankMenu close
    dms ipc call dankMenu refresh         # re-read the menu file

Bind the first one to `Super+Space` in your compositor.

| key | effect |
| --- | --- |
| `Enter` / `Right` | enter a submenu, or run a row and close |
| `Escape` / `Left` | up one level; at the root, close |
| `Backspace` on an empty query | up one level |
| `Up` / `Down`, `Ctrl+P` / `Ctrl+N` | move the selection |
| any text | search this level's whole subtree |

At the root, a search also covers installed applications.

## The menu file

`menu.jsonc` uses Omarchy's schema exactly — object keys are dotted ids,
hierarchy is implied by the dots, and the kind of a row is inferred from its
fields (`action` → action, `target` → link, `provider` → provider, otherwise
submenu). Subtrees of Omarchy's own menu file can be pasted in unchanged.

Rows may carry `when`, `checked` and `disabled` shell snippets: `when` hides
the row unless the snippet succeeds, `checked` appends a tick when it does, and
`disabled` dims and blocks the row. All the snippets for one level run in a
single shell, not one process per row.

Point the `menuPath` setting at another file to replace the tree — that is how
a Nix-managed install supplies a generated one.

## Development

    nix develop ../..
    qmltestrunner -input tests/tst_menumodel.qml
    qmltestrunner -input tests/tst_search.qml
    qmltestrunner -input tests/tst_conditions.qml

`qmltestrunner` takes one `-input` per run and exits with the failure count.
`MenuModel.js`, `Search.js` and `Conditions.js` import no QML types, so the
tests exercise the exact files the plugin loads.
```

- [ ] **Step 2: Add checks to the flake**

In `flake.nix`, add alongside `devShells`:

```nix
      checks = forAll (pkgs: {
        dankmenu-qml = pkgs.runCommand "dankmenu-qml-tests"
          {
            nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
          }
          ''
            export QML_IMPORT_PATH="${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
            export QML2_IMPORT_PATH="$QML_IMPORT_PATH"
            export QT_QPA_PLATFORM=offscreen
            cp -r ${./plugins/dankmenu} dankmenu
            for t in dankmenu/tests/tst_*.qml; do
              echo "== $t"
              qmltestrunner -input "$t"
            done
            touch $out
          '';
      });
```

`QT_QPA_PLATFORM=offscreen` because the sandbox has no display, and
`qmltestrunner` still wants a platform plugin even for tests that never
instantiate a window.

- [ ] **Step 3: Run the checks**

```bash
cd ~/Documents/dms-plugins
nix flake check -L
```

Expected: all three suites run and pass; the derivation succeeds.

- [ ] **Step 4: Commit and push**

```bash
cd ~/Documents/dms-plugins
git add plugins/dankmenu/README.md flake.nix
git commit -m "docs(dankmenu): README, and run the QML suites in flake checks"
git push
```

---

## Task 13: Wire the new repo into sitolamix

**Files:**
- Modify: `~/sitolamix/flake.nix:96-104`
- Modify: `~/sitolamix/modules/desktop/dms/plugins.nix`

**Interfaces:**
- Consumes: `inputs.dms-plugins`.
- Produces: MouthGuard sourced from the new repo; `dankMenu` installed with a Nix-generated tree.

- [ ] **Step 1: Swap the flake input**

Replace `flake.nix:96-104` with:

```nix
    # sitolam/dms-plugins — home-grown DMS plugins (mouthguard, dankmenu), not
    # in dms-plugin-registry, so pinned as its own input. Tracks the repo's
    # default branch; local edits over in the working checkout are picked up
    # only once they are pushed and `nix flake update dms-plugins` is run.
    dms-plugins = {
      url = "github:sitolam/dms-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 2: Update MouthGuard's paths in `plugins.nix`**

Two interpolations change and nothing else — the dlib pin, the `result`
symlink and every comment explaining them stay exactly as they are:

```nix
  mouthGuardDetector = pkgs.writeShellScriptBin "mouthguard-detector" ''
    exec ${mouthGuardPython}/bin/python3 ${inputs.dms-plugins}/plugins/mouthguard/detector.py "$@"
  '';

  mouthGuardPlugin = pkgs.runCommand "dms-plugin-mouthguard" { } ''
    mkdir -p $out
    cp -r ${inputs.dms-plugins}/plugins/mouthguard/. $out/
    chmod -R u+w $out
    ln -s ${mouthGuardDetector} $out/result
  '';
```

Also update the comment block above them: it names `sitolam/dms-mouthguard` and
`the flake input`, both of which have moved.

- [ ] **Step 3: Generate the menu tree from Nix**

Add to the `let` block in `plugins.nix`:

```nix
  # ── dankMenu ──────────────────────────────────────────────────────────────
  # The tree lives here rather than in the plugin so rows can reference this
  # flake's own checkout and this config's packages. The plugin ships its own
  # default tree for anyone installing it standalone; menuPath overrides it.
  #
  # Schema is omarchy's (github:basecamp/omarchy, default/omarchy/omarchy-menu.jsonc):
  # dotted keys imply hierarchy, kind is inferred from the fields, and `when` /
  # `checked` / `disabled` are shell snippets evaluated per menu level.
  flakeDir = "/home/otis/sitolamix";

  dankMenuTree = {
    apps = { icon = "apps"; label = "Apps"; aliases = [ "app" "applications" ]; provider = "apps"; };
    learn = { icon = "school"; label = "Learn"; };
    trigger = { icon = "bolt"; label = "Trigger"; };
    style = { icon = "palette"; label = "Style"; };
    setup = { icon = "settings"; label = "Setup"; aliases = [ "settings" ]; };
    update = { icon = "sync"; label = "Update"; };
    system = { icon = "power_settings_new"; label = "System"; aliases = [ "power-menu" ]; };

    "learn.keybinds" = { icon = "keyboard"; label = "Keybinds"; action = "dms ipc call keybinds toggleBinds"; };
    "learn.niri" = { icon = "grid_view"; label = "Niri"; target = "https://github.com/YaLTeR/niri/wiki"; };
    "learn.nixos" = { icon = "menu_book"; label = "NixOS Manual"; target = "https://nixos.org/manual/nixos/stable/"; };
    "learn.home-manager" = { icon = "home"; label = "Home Manager Options"; target = "https://nix-community.github.io/home-manager/options.xhtml"; };
    "learn.packages" = { icon = "search"; label = "Search Packages"; target = "https://search.nixos.org/packages"; };

    "trigger.capture" = { icon = "screenshot_region"; label = "Capture"; aliases = [ "screenshot" "screenrecord" ]; action = "dms ipc call screenCaptureToolbar toggle"; };
    "trigger.clipboard" = { icon = "content_paste"; label = "Clipboard"; aliases = [ "clip" ]; action = "dms ipc call clipboard toggle"; };
    "trigger.notepad" = { icon = "edit_note"; label = "Notepad"; action = "dms ipc call notepad toggle"; };
    "trigger.emoji" = { icon = "mood"; label = "Emoji"; aliases = [ "emoji" "emojis" ]; action = "dms ipc call spotlight toggleQuery ':e '"; };

    "style.theme" = { icon = "colorize"; label = "Theme"; aliases = [ "theme" "themes" ]; action = "dms ipc call settings open"; };
    "style.wallpaper" = { icon = "wallpaper"; label = "Wallpaper"; aliases = [ "background" ]; action = "dms ipc call wallpaper browse"; };

    "setup.config" = { icon = "code"; label = "Edit Config"; action = "ghostty --working-directory=${flakeDir} -e nvim ${flakeDir}/flake.nix"; };
    "setup.outputs" = { icon = "monitor"; label = "Monitors"; action = "niri msg outputs"; };
    "setup.control-center" = { icon = "tune"; label = "Control Center"; aliases = [ "wifi" "audio" ]; action = "dms ipc call control-center toggle"; };

    # Rebuild verbs run in a terminal so their output is visible; they are
    # long-running and can fail, and a silent detached process would hide both.
    "update.rebuild" = { icon = "build"; label = "Rebuild"; action = "ghostty --working-directory=${flakeDir} -e just rebuild"; };
    "update.update" = { icon = "sync"; label = "Update Inputs + Rebuild"; action = "ghostty --working-directory=${flakeDir} -e just update"; };
    "update.diff" = { icon = "difference"; label = "Diff Generations"; action = "ghostty --working-directory=${flakeDir} -e just diff"; };
    "update.dms-reload" = { icon = "restart_alt"; label = "Restart Shell"; action = "systemctl --user restart dms.service"; };

    "system.lock" = { icon = "lock"; label = "Lock"; action = "loginctl lock-session"; };
    "system.suspend" = { icon = "bedtime"; label = "Suspend"; action = "systemctl suspend"; };
    "system.logout" = { icon = "logout"; label = "Logout"; action = "niri msg action quit --skip-confirmation"; };
    "system.reboot" = { icon = "restart_alt"; label = "Reboot"; action = "systemctl reboot"; };
    "system.shutdown" = { icon = "power_settings_new"; label = "Shutdown"; action = "systemctl poweroff"; };
  };

  dankMenuFile = (pkgs.formats.json { }).generate "dankmenu.json" dankMenuTree;
```

Nix attribute sets do not preserve insertion order — they serialise
alphabetically — so the root reads `apps, learn, setup, style, system,
trigger, update`. That is acceptable and stable; if a specific order is wanted
later, the tree gains an explicit index field and `MenuModel.build` sorts on it.

`ghostty` is unqualified on purpose: it is this config's terminal
(`modules/suites/core.nix:12`), actions run through `bash -lc` so the user PATH
applies, and every other row calls `dms` / `niri` / `systemctl` the same way.
Only `flakeDir` is interpolated, because a checkout path is not on any PATH.

- [ ] **Step 4: Add the plugin entry**

In the `plugins` attrset:

```nix
        # local project (see the `let` block) — omarchy-style root menu, bound
        # to Mod+Space in ../niri/bindings.nix. The tree is generated above so
        # rows can reference this checkout; the plugin's own menu.jsonc is only
        # a standalone-install default.
        dankMenu = {
          enable = true;
          src = "${inputs.dms-plugins}/plugins/dankmenu";
          settings.menuPath = "${dankMenuFile}";
        };
```

- [ ] **Step 5: Build and verify**

```bash
cd ~/sitolamix
nix flake update dms-plugins
just fmt
just check
just drybuild
```

Expected: the flake evaluates, formatting is clean, and the dry build succeeds.

- [ ] **Step 6: Switch and verify both plugins**

```bash
cd ~/sitolamix
just rebuild
rm -f ~/.config/DankMaterialShell/plugins/dankMenu   # drop the dev symlink
systemctl --user restart dms.service
dms ipc call dankMenu open root
```

Expected: MouthGuard's bar pill is still present and functional, and dankMenu
opens showing the Nix-generated tree (`Edit Config` present, which the bundled
tree does not have).

- [ ] **Step 7: Commit**

```bash
cd ~/sitolamix
git add flake.nix flake.lock modules/desktop/dms/plugins.nix
git commit -m "feat(dms): move mouthguard to dms-plugins, add dankMenu

The one-plugin dms-mouthguard input becomes dms-plugins, a monorepo for
home-grown DMS plugins. MouthGuard's assembly is unchanged apart from
the path prefix -- the dlib pin and the result-symlink trick exist for
the same reasons they always did.

dankMenu is an omarchy-style root menu. Its tree is generated here
rather than taken from the plugin so rows can reference this checkout
and this config's packages; the plugin's bundled tree is the
standalone-install default."
```

---

## Task 14: Bind `Mod+Space`

**Files:**
- Modify: `~/sitolamix/modules/desktop/niri/bindings.nix:71-79`

- [ ] **Step 1: Replace the spotlight binds**

```nix
            # omarchy-style root menu (dankMenu plugin, see ../dms/plugins.nix):
            # one key to every command, with its own search and app list. This
            # replaces DMS's spotlight as the general launcher — spotlight is
            # still reachable for its trigger-based plugins, see Mod+Shift+Period.
            "Mod+Space" = spawn (dms [
              "dankMenu"
              "toggle"
              "root"
            ]);
```

and delete the `"Mod+Ctrl+Return"` spotlight binding entirely.

The `dms` helper at the top of this file already prepends `[ "dms" "ipc"
"call" ]` (`bindings.nix:9-16`), which is why the list starts at the target
name — the resulting argv is `dms ipc call dankMenu toggle root`.

- [ ] **Step 2: Build and switch**

```bash
cd ~/sitolamix
just fmt && just check && just rebuild
```

- [ ] **Step 3: Verify by hand**

Expected:
- `Mod+Space` opens dankMenu, not spotlight.
- `Mod+Space` again closes it.
- `Mod+Shift+Period` still opens the emoji picker.
- `Mod+V`, `Mod+P`, `Mod+D` are untouched.

- [ ] **Step 4: Commit**

```bash
cd ~/sitolamix
git add modules/desktop/niri/bindings.nix
git commit -m "feat(niri): Mod+Space opens dankMenu instead of spotlight

Spotlight's general-launcher binds go; its trigger-based plugins are
still reachable through Mod+Shift+Period. dankMenu brings its own app
search, so nothing is lost from the Mod+Space slot."
```

---

## Task 15: Documentation and final verification

**Files:**
- Modify: `~/sitolamix/README.md` (keybinds and plugins sections)
- Modify: `~/sitolamix/docs/superpowers/specs/2026-08-21-dms-plugins-dankmenu-design.md` (status)

- [ ] **Step 1: Update the config README**

In the keybinds table, change the `Mod+Space` row to dankMenu and remove the
`Mod+Ctrl+Return` row. In whatever section lists DMS plugins, add dankMenu with
a one-line description and note that MouthGuard now lives in `dms-plugins`.

- [ ] **Step 2: Mark the spec approved**

Change the spec's `**Status:**` line to `implemented`.

- [ ] **Step 3: Full verification sweep**

```bash
cd ~/Documents/dms-plugins && nix flake check -L
cd ~/sitolamix && just doctor
systemctl --user status dms.service --no-pager | head -5
journalctl --user -u dms --since "5 min ago" | grep -i "dankmenu\|error" | head
```

Expected: checks pass, `just doctor` is clean, the shell is running, and no
dankMenu errors in the log.

- [ ] **Step 4: Confirm the follow-up is recorded, not silently dropped**

The spec's "Known consequence" section notes that the `calculator` plugin
becomes unreachable once spotlight loses its general binds. Confirm that
section still reads accurately after implementation, and leave the decision
open — it is not this plan's to make.

- [ ] **Step 5: Commit**

```bash
cd ~/sitolamix
git add README.md docs/superpowers/specs/2026-08-21-dms-plugins-dankmenu-design.md
git commit -m "docs: dankMenu on Mod+Space, mouthguard moved to dms-plugins"
```

---

## Verification Checklist

- [ ] MouthGuard's pytest suite reports the same pass count as before the move
- [ ] `git log --follow plugins/mouthguard/detector.py` reaches its original commits
- [ ] All three dankMenu JS suites pass under `qmltestrunner`
- [ ] `nix flake check` passes in `dms-plugins`
- [ ] `just doctor` passes in `sitolamix`
- [ ] `Mod+Space` opens dankMenu; Enter descends, Escape ascends, Escape at root closes
- [ ] A query at the root finds both a deep menu leaf and an installed application
- [ ] A `when:false` row is absent and a `checked:true` row shows a tick
- [ ] Launching an app from the menu puts it in its own systemd scope
- [ ] MouthGuard's bar pill still works after the rebuild
