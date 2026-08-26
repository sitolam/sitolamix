# Android suite: adb, scrcpy, and auto-connect on wireless debugging

**Date:** 2026-08-05
**Status:** approved, ready for implementation

## Problem

`adb` is not installed on this machine. `scrcpy` is installed, but only as a
bare package dropped into `suites/development.nix`, with no udev rules, no
`adbusers` group, and none of the launcher ergonomics that existed in the
previous config (`quickhyprnix`, `modules/apps/scrcpy/default.nix`).

The phone (OnePlus 11R 5G) runs wireless adb on a **fixed port 1828**, but its
IP is a DHCP lease and can change. Connecting is currently a manual
`adb connect 192.168.68.166:1828` followed by a manual `scrcpy`.

Goal: `adb` available in the terminal, the old `screen` launcher back, and the
machine noticing on its own when the phone is reachable — surfacing that as a
notification with a button rather than a window that steals focus.

## Solution overview

One module, `modules/apps/android.nix`, gated on `apps.android.enable`, holding
system config, home-manager config, the launcher script, and the watcher
service — per this repo's one-file-per-feature rule.

### The IP problem

The phone's port is stable; its IP is not. Rather than pinning a DHCP
reservation in the router, reuse KDE Connect, which is already enabled
(`modules/services/kde-connect.nix`), already paired with this exact phone, and
already tracks its address. Its D-Bus device object exposes:

```
org.kde.kdeconnect
  /modules/kdeconnect/devices/a1064e6b61e148d4857dc698990e06e2
    org.kde.kdeconnect.device
      .isReachable          b   true            (emits-change)
      .reachableAddresses   as  ["192.168.68.166"]  (emits-change)
```

The watcher resolves the current IP from `reachableAddresses` and falls back to
the configured `apps.android.host` when KDE Connect is unavailable (daemon down,
device unpaired, module disabled).

Device selection is by **paired + reachable phone**, not by hard-coded device
ID: the watcher walks `/modules/kdeconnect/devices/*` and takes the first object
with `isPaired && isReachable && type == "phone"`. A hard-coded ID would break
on re-pairing.

## Module contents

### Options

| Option | Type | Default | Meaning |
|---|---|---|---|
| `apps.android.enable` | bool | false | master switch |
| `apps.android.host` | str | `"192.168.68.166"` | fallback IP when KDE Connect can't answer |
| `apps.android.port` | port | `1828` | wireless adb port (stable on this device) |
| `apps.android.watch.enable` | bool | true | run the auto-connect watcher |

### System config

- `environment.systemPackages = [ pkgs.android-tools ]` — `adb`/`fastboot` in
  the system PATH.

  Originally specified as `programs.adb.enable = true`. That option no longer
  exists on this nixpkgs: systemd 258 applies the USB uaccess rules by itself,
  so the module was removed along with its `adbusers` group. There is
  consequently **no group to join** and `modules/system/users.nix` is untouched.
- Home packages: `scrcpy`, `libnotify` (`notify-send` is **not** currently
  installed anywhere — the watcher needs it).
- No firewall change: `adb connect` is outbound only.

### `screen` — the launcher script

`pkgs.writeShellScriptBin "screen"`, the successor to the quickhyprnix script
(`setsid scrcpy --shortcut-mod=lctrl --show-touches &`). It keeps those flags
and adds:

1. **Single instance.** If a scrcpy process is already running, focus its window
   through `niri msg` instead of spawning a second mirror.
2. **Self-sufficient connect.** If `adb devices` shows no connected device, run
   the same resolve-and-connect the watcher uses, so `screen` works on its own
   whether or not the watcher is running.
3. **Detached launch** via `systemd-run --user --collect --unit=scrcpy-screen`,
   so the mirror outlives its parent — terminal, notification handler, or
   keybind — and a watcher restart cannot take it down.

   With a `setsid` fallback when the transient unit cannot be created. Not
   defensive programming for its own sake: during implementation every
   `StartTransientUnit` call on this machine failed, because `/run/user/1000`
   was 100% full (a dead quickshell instance had left a 1.6 GB `log.log` there)
   and the user manager could not write the unit file. The same fallback covers
   the watcher's notification launch, and the watcher unit sets
   `KillMode = "process"` so that when the fallback is in play a watcher restart
   does not kill the mirror along with the poll loop.

The name `screen` shadows GNU screen. That is intentional and carried over from
the old config; GNU screen is not installed here (tmux is, via
`modules/apps/tmux.nix`).

### `android-adb-watch` — the watcher

A `systemd.user.service` (matching `modules/desktop/niri/default.nix`'s
polkit-agent pattern), `wantedBy = [ "graphical-session.target" ]`,
`Restart = "always"`.

Running as a *user* service is required, not incidental: it must reach the
session's D-Bus for KDE Connect and notifications, and it shares the user's adb
server, so a device it connects shows up in `adb devices` in any terminal.

Poll loop, 15 s interval:

```
ip ← kdeconnect reachableAddresses  (fallback: apps.android.host)
│
├─ TCP probe ip:1828 succeeds?
│   ├─ yes, and state != connected
│   │     → adb connect ip:1828
│   │     → on success: state = connected, fire notification (detached)
│   ├─ yes, and state == connected → nothing
│   └─ (probe uses a short timeout so a dead host can't stall the loop)
│
└─ no, or no reachable device
      → if state == connected: adb disconnect ip:1828, state = disconnected
```

State is a shell variable in the loop, not a file: a watcher restart should
re-announce the phone, and there is no cross-process reader.

Polling rather than subscribing to D-Bus `PropertiesChanged`: wireless adb can
be toggled on the phone *after* KDE Connect reports it reachable, so an
edge-triggered design would still need a retry loop. A 15 s poll of two D-Bus
property reads plus one TCP connect is cheap and has one code path.

### Notification

```
notify-send -a android -i phone -A show="Show screen" \
  "OnePlus 11R 5G connected" "wireless adb on <ip>:1828"
```

`notify-send -A` blocks until the user clicks or the notification expires, then
prints the action key on stdout — so it runs **detached from the poll loop**,
and its handler execs `screen` when the key is `show`.

Verified live on this machine: libnotify 0.8.8, DMS renders the action button
and returns `show` on click.

Fires on **every** new connection (each time the phone becomes newly reachable —
so typically on boot and on rejoining wifi), with no cooldown. Deliberate: it is
a single transient line, and repeat notifications while already connected are
already suppressed by the state check.

### Niri integration

Both live in `android.nix`, guarded by `config.desktop.niri.enable`, so
disabling the module removes them cleanly:

- **Window rule** matching `app-id = "scrcpy"`, deliberately unanchored: with a
  mirror open, `niri msg windows` reports the app-id as **`.scrcpy-wrapped`**,
  because nixpkgs wraps the binary and SDL takes the id from `argv[0]`
  (`SDL_APP_ID` does not override it — tested). Then `open-floating = true`,
  `default-window-height.fixed = 900` with the width left to scrcpy so the
  phone's aspect ratio is preserved, and `opacity = 1.0`. The opacity matters —
  `modules/desktop/niri/rules.nix` makes *every* window 0.8 translucent for the
  blur, which looks wrong on a phone mirror. The rule is contributed with
  `lib.mkAfter` so it lands after the global rule in the merged list; niri
  applies rules in order and the last match wins.
- **Keybind** `Mod+Shift+A` → `screen`. Verified free: `Mod+A` is
  `toggle-column-tabbed-display`, `Mod+Shift+P` is `power-off-monitors`.
- **Desktop entry** "Phone Screen" running `screen`, so DMS Spotlight
  (`Mod+Space`) can launch it too.

This places niri config outside `niri/rules.nix` and `niri/bindings.nix` for the
first time. Chosen knowingly: the README's one-file-per-feature rule takes
precedence over the current centralization, and both options are `listOf` /
`attrsOf` types that merge across modules.

### Suite wiring

`suites/development.nix` drops `scrcpy` from its `home.packages` list and sets
`apps.android.enable = true`.

## Out of scope

- The `scrcpy-camera` v4l2 loopback service from quickhyprnix (persistent
  front-camera capture to `/dev/video1`). Not requested; it would pin a
  permanent capture of the phone camera.
- A DMS control-center tile. That needs a QML plugin authored like
  `mouthGuard`; the notification plus keybind covers the same need. The bar
  already carries the `dankKDEConnect` widget for phone status.
- USB (wired) adb ergonomics beyond what `programs.adb.enable` provides.

## Testing

Nix-level config is verified by `nix flake check` / a successful rebuild. The
runtime behaviour is verified by hand on the live machine, since it depends on
the phone, the session bus, and the compositor:

1. `adb` resolves in a fresh shell; `adb devices` works without sudo (group).
2. With the phone on wifi: watcher connects within 15 s, `adb devices` lists
   `192.168.68.166:1828`, notification appears with a working button.
3. Clicking the button opens scrcpy as a **floating, fully opaque** window.
4. `Mod+Shift+A` with the mirror already open focuses it instead of opening a
   second one.
5. Phone off wifi (airplane mode): watcher disconnects, and reconnecting fires a
   fresh notification.
6. `systemctl --user restart android-adb-watch` does not kill a running mirror.
