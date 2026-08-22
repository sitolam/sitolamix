# Installing `omnibook`

Full procedure for putting this flake on the HP OmniBook (Intel Core Ultra X7
358H, 32 GB RAM), replacing Windows.

Read [Part 0](#part-0--on-gamingpc-before-you-touch-the-laptop) and
[Part 1](#part-1--on-the-laptop-while-windows-still-boots) **before** you boot
the installer. Everything irreversible lives in those two parts.

## What you end up with

```
nvme0n1p1  NIXBOOT   vfat ESP, /boot, unencrypted
nvme0n1p2  NIXCRYPT  LUKS2  ← one passphrase, typed at boot
           └─ vg0    LVM
              ├─ swap  32G   (= RAM, so hibernate works)
              └─ root  rest, ext4
```

GRUB (unencrypted `/boot`) → initrd asks for the passphrase → LVM comes up →
root and swap mount. Secure Boot off, no TPM involvement.

Also: all nine suites including `gaming`, Intel Xe3 graphics on the `xe` driver,
and face unlock on the IR camera.

## Before you begin — have these ready

| | Why |
|---|---|
| A USB stick, ≥4 GB | NixOS installer image |
| Wired ethernet **or** USB phone tethering | The OmniBook's Wi-Fi is a new Intel part; the ISO's kernel may not have firmware for it. Don't find this out with no fallback. |
| `gamingpc` powered on and physically reachable | Needed *mid-install* to re-key the sops secrets. You cannot SSH into it — `modules/system/openssh.nix` is key-only and declares no `authorizedKeys`, so it accepts nobody. Plan to walk between the two machines. |
| 1–2 hours | The first build downloads most of a desktop. |

---

## Part 0 — On `gamingpc`, before you touch the laptop

### 0.1 Commit and push the host config

The installer clones from GitHub, so anything uncommitted does not exist as far
as the laptop is concerned. The `omnibook` host, the howdy module, and the
`amd_pstate` move are currently staged but not committed.

```sh
cd ~/sitolamix
git status                 # confirm what you are about to commit
git commit -m "feat(hosts): add omnibook — HP laptop, LUKS+LVM, howdy face unlock"
git push
```

> [!NOTE]
> Hosts are discovered by reading the **git tree**, not the working directory
> (`flake/systems.nix` calls `builtins.readDir` on a path inside the flake).
> An untracked `hosts/omnibook/` is invisible to `nix build`. If a host seems
> not to exist, `git add` it.

### 0.2 Pre-flight — build it here first

Do this. A build failure discovered *after* you have wiped the laptop is a bad
afternoon; the same failure discovered here costs nothing.

```sh
just check                 # nix flake check --no-build
just drybuild omnibook     # resolves the closure without building
just build omnibook        # optional but recommended: actually builds it
```

`just build omnibook` needs a few GB free — most of the closure is shared with
`gamingpc`, the delta is the Intel media stack, howdy and dlib. Check with
`df -h /nix/store` first; this box runs tight on storage, which is why
`programs.nh.clean` is set to run daily.

This does **not** speed up the laptop's install — it still pulls from
`cache.nixos.org` — it only proves the config evaluates and builds.

### 0.3 Write the installer to USB

Any recent [NixOS ISO](https://nixos.org/download/), graphical or minimal.

```sh
# find the stick — check the size, twice, this command destroys the target
lsblk
sudo dd if=nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

### 0.4 Know what is coming in Part 6

Midway through the install you have to walk back to this machine to add the
laptop as a sops recipient. Nothing to do now — just don't shut `gamingpc` down
and wander off.

---

## Part 1 — On the laptop, while Windows still boots

> [!WARNING]
> **Save your BitLocker recovery key now.** Windows 11 on an HP laptop seals the
> BitLocker key to the TPM. Turning Secure Boot off and switching storage to
> AHCI (Part 2) both change the TPM's PCR measurements, which breaks that seal —
> the next Windows boot will demand a 48-digit recovery key instead of unlocking
> silently.
>
> For a wipe install that does not matter. It matters enormously if you later
> want to boot Windows once more to copy something off.

```powershell
# admin PowerShell
manage-bde -protectors -get C:
```

Or fetch it from <https://account.microsoft.com/devices/recoverykey> if the
laptop is signed in to a Microsoft account.

**Then copy your data off.** Everything on the internal disk is destroyed in
Part 4 — Documents, Downloads, desktop, browser profiles, anything under
`C:\Users\`. Once you flip to AHCI, getting back in is a recovery-key exercise.

---

## Part 2 — Firmware

Power off, then tap **F10** at the HP logo.

1. **Secure Boot → off.** This flake has no lanzaboote or shim setup. With
   Secure Boot on, neither the installer nor the installed system boots.
2. **Storage / SATA mode → AHCI**, not Intel RST (VMD). HP ships RST enabled,
   and with it the NVMe does not appear in `lsblk` at all — there is nothing to
   partition.

Save and exit. `hosts/omnibook/hardware.nix` also carries the `vmd` initrd
module as a fallback, so a system installed in RST mode still boots — but AHCI
is the setting you want.

Windows stops booting after the AHCI switch. Expected.

---

## Part 3 — Boot the installer

Boot from the USB stick (**F9** for the boot menu on HP).

Get networking up and become root:

```sh
sudo -i
nmtui                      # minimal ISO; or plug in ethernet/tethering
ping -c1 cache.nixos.org
```

If Wi-Fi is missing entirely, that is the Intel firmware gap — use the wired
fallback and carry on. It will work on the installed system, which has
`hardware.enableRedistributableFirmware = true`.

Confirm the disk is visible before going further:

```sh
lsblk
```

No `nvme0n1`? You are still in RST mode. Back to Part 2.

---

## Part 4 — Partition — **this erases the disk**

Last exit. After the next command Windows is gone.

```sh
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart NIXBOOT fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart NIXCRYPT 1GiB 100%

mkfs.fat -F32 -n NIXBOOT /dev/nvme0n1p1
```

`parted -- mkpart NIXCRYPT` sets a GPT **partition name**, not a filesystem
label. That is deliberate: a LUKS container has no filesystem label of its own,
and `hosts/omnibook/hardware.nix` opens it as
`/dev/disk/by-partlabel/NIXCRYPT`. Do not substitute `-L`.

### Encrypt

> [!IMPORTANT]
> The unlock prompt appears in the initrd, before any keymap is loaded — it is
> **US-QWERTY no matter what your keyboard is**. On an AZERTY keyboard `a`/`q`,
> `z`/`w`, `m`, and every digit move. Choose a passphrase whose characters sit
> in the same place on both layouts, or you will be locked out of your own disk
> on first boot with no way back in.
>
> Type it out on the installer console first (`cryptsetup` asks twice, which is
> a useful rehearsal).

```sh
cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot
```

### LVM inside the container

```sh
pvcreate /dev/mapper/cryptroot
vgcreate vg0 /dev/mapper/cryptroot
lvcreate -L 32G -n swap vg0
lvcreate -l 100%FREE -n root vg0

mkfs.ext4 -L NIXROOT /dev/vg0/root
mkswap    -L NIXSWAP /dev/vg0/swap
```

32 G of swap for 32 GB of RAM, so a hibernate image always fits.

### Mount

```sh
mount /dev/vg0/root /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/NIXBOOT /mnt/boot
swapon /dev/vg0/swap
```

---

## Part 5 — Clone the flake

It lives in your home directory, not `/etc/nixos`. Clone it straight to where it
will live after boot:

```sh
nix-shell -p git
mkdir -p /mnt/home/otis
git clone https://github.com/sitolam/sitolamix /mnt/home/otis/sitolamix
```

`hosts/omnibook/` is already in there — nothing to generate. Optionally check
what NixOS detects against what is committed:

```sh
nixos-generate-config --root /mnt --show-hardware-config \
  | diff - /mnt/home/otis/sitolamix/hosts/omnibook/hardware.nix
```

Differences in `fileSystems` are expected — the committed file uses
labels and LVM paths, the generated one uses UUIDs. Differences in
`availableKernelModules` are worth reading.

---

## Part 6 — Re-key the sops secrets — **before** installing

`modules/system/sops.nix` decrypts `secrets/ha.yaml` with the machine's SSH host
key, converted to age. A fresh machine is not a recipient, so **the install
fails at build time** if you skip this.

There is an ordering trap: the installed system would normally generate its host
key on first boot, but you need that key *now* to add it as a recipient. So
create it by hand, in the installer:

```sh
mkdir -p /mnt/etc/ssh
ssh-keygen -t ed25519 -N "" -C "omnibook" -f /mnt/etc/ssh/ssh_host_ed25519_key
chmod 600 /mnt/etc/ssh/ssh_host_ed25519_key
```

NixOS preserves an existing host key rather than replacing it, so sshd adopts
this one.

> [!WARNING]
> Back up `/mnt/etc/ssh/ssh_host_ed25519_key`. Lose it and this machine can
> never decrypt `secrets/*.yaml` again.

Print the age recipient:

```sh
nix run nixpkgs#ssh-to-age < /mnt/etc/ssh/ssh_host_ed25519_key.pub
# age1... — write this down, you are about to walk it across the room
```

### Now on `gamingpc`

It is the only current recipient, so it is the only machine that can re-encrypt.

Add the key to `.sops.yaml`:

```yaml
keys:
  - &gamingpc age1lag4wn9wz90qmfkwcgq55sg56htag4hpfnkxj4ur0mm0txwr4yeq7xpsrr
  - &omnibook age1...            # the key you just printed
creation_rules:
  - path_regex: secrets/[^/]+\.yaml$
    key_groups:
      - age:
          - *gamingpc
          - *omnibook
```

`.sops.yaml` only governs *new* files, so re-encrypt the existing one and push:

```sh
cd ~/sitolamix
nix run nixpkgs#sops -- updatekeys secrets/ha.yaml
git commit -am "chore(sops): add omnibook as a recipient"
git push
```

### Back on the laptop

```sh
cd /mnt/home/otis/sitolamix && git pull
```

Both machines can now decrypt.

---

## Part 7 — Install

```sh
nixos-install --flake /mnt/home/otis/sitolamix#omnibook
```

Long first run, lots of downloading. The noctalia / niri / nix-community caches
in `flake.nix`'s `nixConfig` cover most of the non-nixpkgs closure.

Set the user password before rebooting, or greetd has nothing to let you in
with:

```sh
nixos-enter --root /mnt -c 'passwd otis'
reboot
```

Pull the USB stick as it restarts.

---

## Part 8 — First boot

Order of events: GRUB → **LUKS passphrase prompt** → DMS greeter → desktop.

```sh
sudo chown -R otis:users ~/sitolamix    # it was cloned as root
gh auth login                            # so `git push` works
```

The checkout is already at `~/sitolamix`, which is what the dankMenu
`Update ▸ Rebuild` rows assume (`flakeDir` in
`modules/desktop/dms/plugins.nix`). From here on it is `just rebuild`.

Monitors are configured in DMS's settings UI, not in the flake.

Sanity checks worth doing while you remember:

```sh
lsmod | grep -w xe                       # Xe3 graphics on the xe driver
cat /proc/swaps                          # /dev/vg0/swap present
systemctl hibernate                      # then power on and confirm the session returns
nmcli device status                      # Wi-Fi actually works now
```

---

## Part 9 — Face unlock

Declarative config, machine-specific enrollment. `hardware.howdy.enable` is
already on; the camera node and the face models are not something that can be
committed.

> [!WARNING]
> **Howdy is weaker than Windows Hello.** Hello does a depth / structured-light
> liveness check; howdy compares a flat infrared image and can be fooled by a
> well-printed photo or a phone screen.
>
> It is wired as convenience, not as a security upgrade:
> `control = "sufficient"` means a match unlocks and a miss falls silently
> through to the password prompt, and it is scoped to three PAM services —
> `login` (what the DMS lock screen authenticates against), `greetd`, and
> `sudo`. Not `sshd`. Your password keeps working everywhere.
>
> For face-as-second-factor instead, set `hardware.howdy.control = "required"` —
> then a failed scan *blocks* login rather than falling back.

### 1. Find the IR camera

A Windows Hello module enumerates as two V4L2 devices: the colour webcam and the
infrared one. Only the IR node works in the dark, which is the entire point.

```sh
v4l2-ctl --list-devices
sudo howdy -U otis test        # opens a preview; check it is the IR one
ls -l /dev/v4l/by-path/        # get the stable path
```

### 2. Point the config at it

`/etc/howdy/config.ini` is a read-only symlink into the nix store, so
`howdy set` **cannot** work. Set it in Nix:

```nix
# hosts/omnibook/default.nix
hardware.howdy = {
  enable = true;
  device = "/dev/v4l/by-path/pci-0000:00:14.0-usb-0:8:1.0-video-index2";
};
```

Prefer the `by-path` symlink over a bare `/dev/video2` — the numbering shifts
when another camera is plugged in, and a howdy pointed at the wrong node just
fails every scan. Then `just rebuild`.

### 3. Enrol

```sh
sudo howdy -U otis add        # repeat: glasses on, glasses off, dim room
sudo howdy -U otis list
sudo howdy -U otis remove 0
```

Lock with `Super+L` to try it.

### 4. If every frame is black

Some Windows Hello modules need their IR LEDs switched on explicitly.

```nix
hardware.howdy.irEmitter.enable = true;
```

`just rebuild`, then the one-off probe:

```sh
sudo linux-enable-ir-emitter configure
```

### Turning it off

`hardware.howdy.enable = false;` and `just rebuild` — PAM goes back to
password-only immediately. Models stay in `/var/lib/howdy/models`; delete the
directory to remove them.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| No `nvme0n1` in `lsblk` | Still in Intel RST mode — Part 2 |
| Installer will not boot | Secure Boot still on — Part 2 |
| Build fails on `sops` / `hass_token` | Part 6 skipped, or the `git pull` after it |
| Passphrase rejected on first boot, correct on the installer | Keyboard layout — the initrd prompt is US-QWERTY |
| Hibernate writes then cold-boots | `boot.resumeDevice` unset. It is set in `hardware.nix`; check `cat /proc/cmdline` for `resume=/dev/vg0/swap` |
| No Wi-Fi after install | `dmesg \| grep iwlwifi`; tether over USB in the meantime |
| Black frames in `howdy test` | Wrong video node, or the IR emitter — Part 9 steps 1 and 4 |
| Face never matches | Almost always the colour camera instead of the IR one |

## Checklist

- [ ] 0.1 committed and pushed
- [ ] 0.2 `just build omnibook` passes on `gamingpc`
- [ ] 0.3 ISO on USB
- [ ] 1 BitLocker recovery key saved
- [ ] 1 data copied off Windows
- [ ] 2 Secure Boot off, AHCI on
- [ ] 4 passphrase chosen with the US-QWERTY prompt in mind
- [ ] 6 host key generated **and backed up**
- [ ] 6 `.sops.yaml` updated, `updatekeys` run, pushed, pulled on the laptop
- [ ] 7 `passwd otis` before reboot
- [ ] 8 hibernate tested
- [ ] 9 howdy device path committed
