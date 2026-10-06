"""Map the pen tablet to one screen at a time, for the monitors connected now.

usage: tablet-sync SETTINGS_JSON [--watch]

Writes one OpenTabletDriver preset per screen from SETTINGS_JSON and applies
the one for the focused screen. Tablet key 1 then cycles through them.
With --watch, repeats whenever a monitor is plugged in or removed.
"""

import copy
import fcntl
import glob
import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import time

CFG = os.path.expanduser("~/.config/OpenTabletDriver")
PRESET_BINDING = "OpenTabletDriver.Desktop.Binding.PresetBinding"
VIRTUAL_TABLET = "OpenTabletDriver Virtual Artist Tablet"
EVIOCGABS = 0x80184540  # + axis


def otd(*args):
    return subprocess.run(["otd", *args], check=True, capture_output=True, text=True).stdout


def wait_for_driver():
    for _ in range(60):
        try:
            return otd("listdisplays")
        except (subprocess.CalledProcessError, FileNotFoundError):
            time.sleep(0.5)
    sys.exit("tablet-sync: OpenTabletDriver daemon is not answering")


def displays(listing):
    """(name, width, height, x, y) per real screen, left to right, plus the whole desktop's size."""
    screens, desktop = [], None
    for line in listing.splitlines():
        m = re.match(r"\d+: (\S+) .*\((\d+)x(\d+)@<(-?\d+), (-?\d+)>\)", line)
        if not m:
            continue
        if m[1] == "Virtual":
            desktop = (int(m[2]), int(m[3]))
        else:
            screens.append((m[1], *map(int, m.groups()[1:])))
    return sorted(screens, key=lambda s: (s[3], s[4])), desktop


def virtual_tablet_size():
    for dev in glob.glob("/sys/class/input/event*"):
        try:
            if open(dev + "/device/name").read().strip() != VIRTUAL_TABLET:
                continue
            fd = os.open("/dev/input/" + os.path.basename(dev), os.O_RDONLY | os.O_NONBLOCK)
            try:
                axes = [struct.unpack("6i", fcntl.ioctl(fd, EVIOCGABS + a, b"\0" * 24)) for a in (0, 1)]
            finally:
                os.close(fd)
            # OpenTabletDriver 0.6 sets the axis maximum to the desktop size in pixels x 1000
            return tuple(round(a[2] / 1000) for a in axes)
        except OSError:
            pass
    return None


def focused_screen():
    try:
        out = subprocess.run(["niri", "msg", "-j", "focused-output"], capture_output=True, text=True).stdout
        return json.loads(out)["name"]
    except (OSError, ValueError, KeyError, TypeError):
        return None


def sync(template):
    screens, desktop = displays(wait_for_driver())
    # The virtual pen device keeps the desktop size it was created with, so
    # after a layout change the pen would cover the wrong area until the
    # daemon is restarted.
    size = virtual_tablet_size()
    if size and desktop and size != desktop:
        subprocess.run(["systemctl", "--user", "restart", "opentabletdriver.service"], check=True)
        time.sleep(1)
        screens, desktop = displays(wait_for_driver())
    if not screens:
        print("tablet-sync: no screens, nothing to do")
        return

    # OpenTabletDriver's origin is the top-left corner of all screens together.
    ox, oy = min(s[3] for s in screens), min(s[4] for s in screens)
    names = [f"screen-{s[0]}" for s in screens]
    os.makedirs(f"{CFG}/Presets", exist_ok=True)
    for old in glob.glob(f"{CFG}/Presets/screen-*.json"):
        os.remove(old)

    built = {}
    for i, (name, w, h, x, y) in enumerate(screens):
        settings = copy.deepcopy(template)
        for profile in settings["Profiles"]:
            area = profile["AbsoluteModeSettings"]
            full = area["Tablet"]
            fw, fh = full["Width"], full["Height"]
            area["Display"] = {"Width": w, "Height": h, "X": x - ox + w / 2, "Y": y - oy + h / 2, "Rotation": 0.0}
            # Largest part of the tablet with the screen's shape, so nothing is stretched.
            tw = min(fw, fh * w / h)
            area["Tablet"] = {"Width": round(tw, 2), "Height": round(tw * h / w, 2), "X": fw / 2, "Y": fh / 2, "Rotation": 0.0}
            profile["Bindings"]["AuxButtons"][0] = {
                "Path": PRESET_BINDING,
                "Settings": [{"Property": "Preset", "Value": names[(i + 1) % len(names)]}],
                "Enable": True,
            }
        built[name] = settings
        with open(f"{CFG}/Presets/{names[i]}.json", "w") as f:
            json.dump(settings, f, indent=2)

    focus = focused_screen()
    start = focus if focus in built else screens[0][0]
    with tempfile.NamedTemporaryFile("w", suffix=".json") as f:
        json.dump(built[start], f)
        f.flush()
        otd("loadsettings", f.name)
    otd("savedefaultsettings")
    print(f"tablet mapped to {start}; key 1 cycles: {' -> '.join(s[0] for s in screens)}", flush=True)


def watch(template):
    sync(template)
    monitor = subprocess.Popen(
        ["udevadm", "monitor", "--udev", "--subsystem-match=drm"], stdout=subprocess.PIPE, text=True
    )
    last = 0.0
    for line in monitor.stdout:
        if not line.startswith("UDEV") or time.monotonic() - last < 5:
            continue
        time.sleep(3)  # let the compositor finish arranging the outputs
        try:
            sync(template)
        except subprocess.CalledProcessError as e:
            print(f"tablet-sync: {e.stderr or e}", flush=True)
        last = time.monotonic()


def main():
    args = [a for a in sys.argv[1:] if a != "--watch"]
    with open(args[0]) as f:
        template = json.load(f)
    (watch if "--watch" in sys.argv else sync)(template)


main()
