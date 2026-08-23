---
name: mount-network-drive
description: Use when the user wants a network share (SMB/CIFS or NFS) to mount automatically at boot or on first access, without being prompted for a password. Discovers the share the user is currently using, then adds a declarative NixOS mount to this flake with credentials held in sops-nix. Examples: "make my network drive mount automatically", "stop asking me for the share password", "add the NAS share to my config".
tools: Bash, Read, Edit, Write, Grep, Glob
---

# Automatic network share mounting

Your job is to turn an ad-hoc network share into a declarative, password-free
mount in this NixOS flake. Work in the repository at `/home/otis/sitolamix`,
and follow its existing conventions: every feature is a module under `modules/`
exposing a single `enable` option, guarded by `lib.mkIf`, and hosts opt in from
`hosts/<host>/default.nix`.

## 1. Discover the share

Do not ask the user for details you can find yourself. Look, in order:

- `mount | grep -Ei 'cifs|nfs|fuse.sshfs'` — an active kernel mount.
- `gio mount -l` and `ls /run/user/$UID/gvfs/` — a GVFS/Nautilus mount. The
  directory name encodes the protocol, server, and share, for example
  `smb-share:server=nas.local,share=media`.
- `~/.config/gtk-3.0/bookmarks` and `~/.local/share/recently-used.xbel` — a
  share the user has visited before but has not mounted right now.
- `journalctl --user -b | grep -i 'smb\|cifs\|gvfs'` — recent mount attempts.

If none of these turn anything up, ask the user for the share URL (for example
`smb://nas.local/media`) and the username, and nothing else. Never ask for the
password in chat; see step 3.

Once you have a candidate, confirm what you found with the user before writing
any configuration: the protocol, server, share name, username, and the mount
point you intend to use (default to `/mnt/<share>` for a system mount).

## 2. Write the module

Create `modules/services/network-shares.nix` if it does not already exist,
following the shape of `modules/services/rclone.nix`. Expose an option that
takes a set of shares so a second one can be added later without touching the
module body, for example:

```nix
options.services.networkShares = {
  enable = lib.mkEnableOption "declarative SMB/NFS mounts";
  shares = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule { ... }); default = { }; };
};
```

Implement the mount with `fileSystems.<mountpoint>` rather than a hand-written
systemd unit. For an SMB share the important options are:

- `fsType = "cifs"`.
- `credentials=<path>` pointing at the sops-decrypted credentials file. This is
  what removes the password prompt.
- `uid`/`gid` set to the user so files are writable without `sudo`, and
  `file_mode=0644,dir_mode=0755`.
- `x-systemd.automount`, `noauto`, and `x-systemd.idle-timeout=60` so the share
  mounts on first access instead of blocking boot, and unmounts when idle.
- `x-systemd.requires=network-online.target` and
  `x-systemd.after=network-online.target`, so a mount attempt during early boot
  does not fail on a missing network. For a laptop that roams between networks,
  also set `x-systemd.mount-timeout=10` and `_netdev` so a failed mount degrades
  instead of hanging the boot.

For NFS the equivalent is `fsType = "nfs"` with `x-systemd.automount` and
`noauto`; NFS needs no credentials file, so step 3 does not apply.

Add `pkgs.cifs-utils` to `environment.systemPackages` inside the same `mkIf`.

## 3. Handle the password with sops-nix

This flake already uses sops-nix — read `modules/system/sops.nix` and
`.sops.yaml` before doing anything, and follow the pattern already there for
declaring a secret and its `path`.

The credentials file must be in the format `mount.cifs` expects:

```
username=<user>
password=<password>
domain=<domain, if any>
```

Store that whole file as a single sops secret so the decrypted path can be
handed straight to the `credentials=` mount option. Give the secret
`mode = "0400"` and `owner = "root"`, since the kernel reads it as root at
mount time.

You cannot encrypt the password yourself — you must not ask the user to paste a
password into the conversation. Instead, add the secret declaration, then tell
the user the exact command to run themselves to fill it in, for example:

```
sops secrets/<file>.yaml
```

and show them the key and value shape to add. Make clear that the rebuild will
fail until the secret exists.

## 4. Wire it up and verify

- Enable the module in the relevant `hosts/<host>/default.nix`, matching the
  style of the other service blocks there.
- Run `nix flake check` or `just doctor`, whichever the `Justfile` provides, and
  report the result honestly. Do not run a system rebuild yourself unless the
  user asks.
- Tell the user how to test: `ls /mnt/<share>` should trigger the automount, and
  `systemctl status $(systemd-escape -p --suffix=mount /mnt/<share>)` shows what
  happened if it does not.

## Constraints

- Never write a plaintext password into a `.nix` file, into `/etc`, or into the
  Nix store. Anything in the store is world-readable; that is the whole reason
  the credentials file goes through sops.
- Never add a `noauto`-less blocking mount to a laptop that may be off the
  network at boot.
- Keep comments in the style of this repository: explain why a setting is there,
  not what the line does.
