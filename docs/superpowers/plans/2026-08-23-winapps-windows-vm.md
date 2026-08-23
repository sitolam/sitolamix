# WinApps Windows VM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run Microsoft Office on both NixOS machines as ordinary desktop windows, backed by a Windows VM that starts only when asked from dankMenu.

**Architecture:** A `dockurr/windows` container declared through `virtualisation.oci-containers` with `autoStart = false`, so NixOS generates `docker-windows.service` but nothing runs at boot. The container's `/oem` hook installs Office 365 unattended on first boot. WinApps connects over loopback RDP in RemoteApp mode with `WAFLAVOR="manual"`, so it never fights systemd for control of the container. dankMenu starts and stops the unit; the `dockerManager` DMS plugin shows its status.

**Tech Stack:** NixOS (flake-parts, import-tree), home-manager via `home.extraOptions`, sops-nix, Docker, `github:winapps-org/winapps`, DankMaterialShell plugins.

**Spec:** `docs/superpowers/specs/2026-08-23-winapps-windows-vm-design.md`

## Global Constraints

- **Nothing runs at boot.** `autoStart = false` on the container, and the unit must not end up in `multi-user.target`'s wants. This is the single requirement most likely to regress silently; it is verified explicitly in Task 7.
- **Ports bind to loopback only.** Every port mapping is prefixed `127.0.0.1:`. An unprefixed mapping publishes an RDP host with a known password onto every network the laptop joins.
- **No password in the Nix store.** Store paths are world-readable. VM credentials live in a sops secret and reach the container through `environmentFiles`, never through `environment`.
- **No activation circumvention.** Do not port `install-winkey.ps1` or `install-nevergreen.ps1` from the reference config. Windows and Office are licensed by the user signing in.
- **Windows edition must have an RDP host.** `VERSION = "11l"` (Windows 11 IoT Enterprise LTSC). Home editions cannot accept RDP connections and will fail at the last step with a confusing error.
- **Office app ids must be the `-o365` variants.** `word-o365`, not `word`. The unsuffixed ids point at MSI install paths; the Office Deployment Tool produces a click-to-run install under `C:\Program Files\Microsoft Office\root\Office16\`, which is what the `-o365` definitions target.
- **This repo's module shape:** one feature per file (or per directory), a single `lib.mkEnableOption`, everything under `lib.mkIf cfg.enable`, home-manager config attached via `home.extraOptions`. Every file under `modules/` is auto-imported by `import-tree`; there is no import list to update.
- **Formatting:** run `nix fmt` before every commit. CI-equivalent is `just check`.

## File Structure

| File | Responsibility |
|---|---|
| `flake.nix` | Add the `winapps` input (modify) |
| `modules/services/winapps/default.nix` | Create. Options, assertions, the container, tmpfiles, polkit, the sops secret declaration |
| `modules/services/winapps/oem.nix` | Create. The first-boot `install.bat` and `configuration.xml`, and the tmpfiles rules that place them |
| `modules/services/winapps/home.nix` | Create. `winapps.conf`, generated desktop entries, the app-definition directory, the `winapps` package |
| `modules/desktop/dms/plugins.nix` | Modify. Enable `dockerManager`; add the `windows` dankMenu subtree |
| `hosts/omnibook/default.nix` | Modify. `services.winapps.enable = true` |
| `hosts/gamingpc/default.nix` | Modify. Same, with more RAM and cores |
| `secrets/winapps.yaml` | Create (by the user, with `sops`). VM account credentials |

The three module files split by *when they run*, not by technical layer: `default.nix` is system state, `oem.nix` is one-shot guest provisioning, `home.nix` is per-user desktop integration. They communicate only through `config.services.winapps`, so none of them imports another.

## A note on testing

This is a NixOS configuration, not an application: there is no test runner, and "write a failing test first" translates to "write a check that fails now and passes after the change." Each task below opens with a concrete `nix eval` or `nix build` command whose failure you should see with your own eyes before implementing, and which must pass afterwards. Do not skip the failing run — it is what proves the check is actually testing the thing you changed.

Two commands recur:

```bash
just check      # nix flake check --no-build
just drybuild   # dry build of this host's toplevel
```

`just doctor` runs both.

---

### Task 1: Add the winapps flake input

**Files:**
- Modify: `flake.nix` (inputs block, after the `helium` entry)

**Interfaces:**
- Produces: `inputs.winapps.packages.<system>.winapps` — the WinApps launcher package. Its wrapper already puts `freerdp 3.26` and `libressl`'s `nc` on `PATH`, so no separate FreeRDP dependency is needed anywhere in this plan.

- [ ] **Step 1: Verify the input does not exist yet**

Run:

```bash
nix eval .#nixosConfigurations.omnibook.config.system.build.toplevel --apply 'x: "ok"' 2>&1 | tail -1
grep -c 'winapps' flake.nix
```

Expected: the `grep -c` prints `0`.

- [ ] **Step 2: Add the input**

In `flake.nix`, in the `inputs` block, after the `helium.url` line:

```nix
    # winapps-org/winapps — runs a single Windows application over RDP in
    # RemoteApp mode, so it paints as its own native window rather than inside a
    # desktop. Not in nixpkgs. The flake exposes `packages` only (no NixOS
    # module), so modules/services/winapps does all the wiring itself; the
    # package's wrapper already carries FreeRDP 3.
    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 3: Lock it and confirm it builds**

Run:

```bash
nix flake lock
nix build --no-link --print-out-paths .#nixosConfigurations.omnibook.pkgs.hello 2>/dev/null || true
nix build --no-link --print-out-paths 'github:winapps-org/winapps#winapps'
```

Expected: the last command prints a store path ending in `-winapps-0-unstable-<date>`.

- [ ] **Step 4: Confirm the app definitions are in that store path**

Run:

```bash
ls "$(nix build --no-link --print-out-paths 'github:winapps-org/winapps#winapps')/src/apps" | grep -c -- '-o365$'
```

Expected: a number greater than 5. These are the definitions Task 5 reads.

- [ ] **Step 5: Commit**

```bash
nix fmt
git add flake.nix flake.lock
git commit -m "feat(flake): add winapps input"
```

---

### Task 2: Create the VM credentials secret

**Files:**
- Create: `secrets/winapps.yaml` (encrypted, created by the user)

**Interfaces:**
- Produces: a sops secret named `winapps_vm_env` whose decrypted content is a systemd `EnvironmentFile`:

  ```
  USERNAME=otis
  PASSWORD=<generated>
  ```

  Consumed by Task 3 (`environmentFiles` on the container) and Task 5 (generating `winapps.conf`).

This task is the one place where the implementing agent must stop and hand back to the user: the plaintext password must never appear in the conversation, in a file in the repo, or in a shell history.

- [ ] **Step 1: Confirm the secret does not exist**

Run:

```bash
ls secrets/
```

Expected: `anki.yaml` and `ha.yaml` only.

- [ ] **Step 2: Generate a password and create the secret — user action**

Tell the user to run these two commands themselves, in their own terminal:

```bash
# generate a password, copy the output
head -c 18 /dev/urandom | base64 | tr -d '/+=' | head -c 20; echo

# create the encrypted secret
sops secrets/winapps.yaml
```

and, in the editor sops opens, to enter exactly:

```yaml
winapps_vm_env: |
  USERNAME=otis
  PASSWORD=<the generated password>
```

Two details that will otherwise cost an hour:

- The `|` block scalar matters. The value is a whole file, not a single line.
- `.sops.yaml`'s `creation_rules` already covers `secrets/[^/]+\.yaml$` for both hosts' age keys, so no `.sops.yaml` change is needed.

Note the password down somewhere — it is the Windows account password, needed for the one interactive sign-in and any future RDP login.

- [ ] **Step 3: Verify it encrypted correctly**

Run:

```bash
grep -q 'ENC\[' secrets/winapps.yaml && echo "encrypted"
grep -c 'PASSWORD=' secrets/winapps.yaml
```

Expected: prints `encrypted`, and the `grep -c` prints `0` — the plaintext must not be visible.

- [ ] **Step 4: Commit**

```bash
git add secrets/winapps.yaml
git commit -m "feat(secrets): add winapps VM account credentials"
```

---

### Task 3: The module — options, container, privilege

**Files:**
- Create: `modules/services/winapps/default.nix`

**Interfaces:**
- Consumes: `config.sops.secrets.winapps_vm_env.path` (Task 2).
- Produces:
  - `services.winapps.enable : bool`
  - `services.winapps.version : str` (default `"11l"`)
  - `services.winapps.ram : str` (default `"4G"`)
  - `services.winapps.disk : str` (default `"64G"`)
  - `services.winapps.cores : int` (default `4`)
  - `services.winapps.sharedDir : str` (default `"/home/otis/Windows"`)
  - `services.winapps.stateDir : str` (default `"/var/lib/winapps"`)
  - `services.winapps.apps : listOf (submodule { id : str; label : str; icon : str; })`
  - the systemd unit `docker-windows.service`

  Tasks 4, 5 and 6 all read `config.services.winapps`; nothing else crosses between files.

- [ ] **Step 1: Write the failing check**

The check is that the option exists and the unit is generated but not wanted at boot. Run it now, before writing anything:

```bash
nix eval .#nixosConfigurations.omnibook.config.services.winapps.enable
```

Expected: FAIL with `error: attribute 'winapps' missing`.

- [ ] **Step 2: Create the module**

Create `modules/services/winapps/default.nix`:

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.winapps;
in
{
  options.services.winapps = {
    enable = lib.mkEnableOption ''
      an on-demand Windows VM (dockurr/windows) whose applications are launched
      as native windows over RDP. Deliberately not started at boot — see the
      `windows` subtree in ../desktop/dms/plugins.nix for the controls
    '';

    version = lib.mkOption {
      type = lib.types.str;
      default = "11l";
      description = ''
        dockurr/windows VERSION. `11l` is Windows 11 IoT Enterprise LTSC: the
        smallest image that still ships an RDP *host*. Home editions can only
        act as RDP clients and will never accept a WinApps connection.
      '';
    };

    ram = lib.mkOption {
      type = lib.types.str;
      default = "4G";
      description = "RAM handed to the guest. 4G is the floor for Windows 11 plus Office.";
    };

    disk = lib.mkOption {
      type = lib.types.str;
      default = "64G";
      description = ''
        Virtual disk size. Sparse — it does not consume this up front. 32G is
        enough to install into and not enough to survive a year of Windows
        updates.
      '';
    };

    cores = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "vCPUs handed to the guest.";
    };

    sharedDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/otis/Windows";
      description = "Host directory exposed inside Windows as `\\\\host.lan\\Data`.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/winapps";
      description = "Holds the VM's virtual disk and the first-boot OEM scripts.";
    };

    apps = lib.mkOption {
      description = ''
        Windows applications to surface. `id` must name a directory under
        `<winapps>/src/apps`; `label` and `icon` are used for the dankMenu rows
        (icon names are Material Symbols, as everywhere else in DMS).

        The `-o365` ids target `C:\Program Files\Microsoft Office\root\Office16`,
        which is where the Office Deployment Tool installs. The unsuffixed ids
        target MSI install paths and will not resolve here.
      '';
      default = [
        {
          id = "word-o365";
          label = "Word";
          icon = "description";
        }
        {
          id = "excel-o365";
          label = "Excel";
          icon = "table";
        }
        {
          id = "powerpoint-o365";
          label = "PowerPoint";
          icon = "slideshow";
        }
        {
          id = "outlook-o365";
          label = "Outlook";
          icon = "mail";
        }
        {
          id = "onenote-o365";
          label = "OneNote";
          icon = "edit_note";
        }
      ];
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            id = lib.mkOption { type = lib.types.str; };
            label = lib.mkOption { type = lib.types.str; };
            icon = lib.mkOption { type = lib.types.str; };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    # Docker itself comes from suites.development, which both hosts enable.
    # Asserting rather than enabling it keeps one owner for the daemon, and
    # turns "I dropped the development suite" into an evaluation error instead
    # of a unit that fails at 2am.
    assertions = [
      {
        assertion = config.services.docker.enable;
        message = "services.winapps needs services.docker (provided by suites.development).";
      }
    ];

    # Account credentials for the guest. Read by systemd as root when starting
    # the container, and by the activation script in ./home.nix — hence owner
    # `otis` rather than `root`: root can read it either way, and this avoids a
    # second copy of the same secret.
    sops.secrets.winapps_vm_env = {
      sopsFile = ../../../secrets/winapps.yaml;
      owner = "otis";
      mode = "0400";
    };

    virtualisation.oci-containers.backend = "docker";

    virtualisation.oci-containers.containers.windows = {
      image = "dockurr/windows";

      # The whole point. NixOS still generates docker-windows.service; it just
      # is not pulled in by multi-user.target, so the VM exists only when
      # something starts it.
      autoStart = false;

      environment = {
        VERSION = cfg.version;
        RAM_SIZE = cfg.ram;
        DISK_SIZE = cfg.disk;
        CPU_CORES = toString cfg.cores;
      };

      # USERNAME and PASSWORD arrive here rather than above because
      # `environment` is rendered into the unit file in the world-readable Nix
      # store.
      environmentFiles = [ config.sops.secrets.winapps_vm_env.path ];

      volumes = [
        "${cfg.stateDir}/storage:/storage"
        "${cfg.stateDir}/oem:/oem"
        "${cfg.sharedDir}:/shared"
      ];

      # Loopback prefixes are load-bearing: without them Docker publishes RDP on
      # every interface. RDP needs both protocols.
      ports = [
        "127.0.0.1:8006:8006/tcp"
        "127.0.0.1:3389:3389/tcp"
        "127.0.0.1:3389:3389/udp"
      ];

      extraOptions = [
        "--device=/dev/kvm"
        "--device=/dev/net/tun"
        "--cap-add=NET_ADMIN"
        # Windows needs to be asked to shut down, and then given time to do it.
        "--stop-timeout=120"
      ];
    };

    # Longer than the container's own stop-timeout, so systemd does not SIGKILL
    # the container mid-shutdown and corrupt the guest filesystem.
    systemd.services.docker-windows.serviceConfig.TimeoutStopSec = 150;

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 root root -"
      "d ${cfg.stateDir}/storage 0755 root root -"
      "d ${cfg.stateDir}/oem 0755 root root -"
      "d ${cfg.sharedDir} 0755 otis users -"
    ];

    # Starting and stopping a *system* unit needs root, and a menu entry that
    # opens a password prompt every time is not a menu entry anybody uses.
    # Scoped as narrowly as polkit allows: this one unit, these two verbs, this
    # one group. Notably `restart` is not granted, and neither is any other
    # unit — `systemctl restart docker.service` still prompts.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "docker-windows.service" &&
            (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
```

- [ ] **Step 3: Run the check again**

```bash
nix eval .#nixosConfigurations.omnibook.config.services.winapps.enable
```

Expected: `false` (declared, not yet enabled by any host).

- [ ] **Step 4: Verify the defaults and that evaluation is clean**

```bash
nix eval .#nixosConfigurations.omnibook.config.services.winapps.disk
just check
```

Expected: `"64G"`, then `just check` passes.

- [ ] **Step 5: Commit**

```bash
nix fmt
git add modules/services/winapps/default.nix
git commit -m "feat(winapps): on-demand Windows container, not started at boot"
```

---

### Task 4: First-boot provisioning — RDP, RemoteApp, Office

**Files:**
- Create: `modules/services/winapps/oem.nix`

**Interfaces:**
- Consumes: `config.services.winapps.{enable,stateDir}` (Task 3).
- Produces: `${stateDir}/oem/install.bat` and `${stateDir}/oem/configuration.xml` on disk, refreshed on every activation.

`dockurr/windows` copies everything in `/oem` into the guest and runs `install.bat` there, once, as administrator, at the end of the unattended install.

- [ ] **Step 1: Write the failing check**

```bash
nix eval --raw .#nixosConfigurations.omnibook.config.systemd.tmpfiles.rules --apply 'rs: builtins.concatStringsSep "\n" rs' | grep install.bat
```

Expected: FAIL (no output, exit 1) — nothing places the file yet.

- [ ] **Step 2: Create the module**

Create `modules/services/winapps/oem.nix`:

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.winapps;

  # Office Deployment Tool answer file. `MatchOS` follows the guest's language;
  # the excluded apps are the ones nobody asked for and which slow the install
  # measurably. AUTOACTIVATE is 0 because activation happens through the one
  # interactive Microsoft 365 sign-in, not through a key baked into the config.
  officeConfig = pkgs.writeText "winapps-office-configuration.xml" ''
    <Configuration>
      <Add OfficeClientEdition="64" Channel="Current">
        <Product ID="O365ProPlusRetail">
          <Language ID="MatchOS" />
          <ExcludeApp ID="Groove" />
          <ExcludeApp ID="Lync" />
          <ExcludeApp ID="Bing" />
          <ExcludeApp ID="Teams" />
        </Product>
      </Add>
      <Display Level="None" AcceptEULA="TRUE" />
      <Property Name="AUTOACTIVATE" Value="0" />
      <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
    </Configuration>
  '';

  # Runs once, as administrator, at the end of the unattended Windows install.
  # Line endings must be CRLF — cmd.exe mis-parses a LF-only batch file in ways
  # that look like syntax errors in unrelated lines.
  installBat = pkgs.runCommand "winapps-install.bat" { } ''
    ${pkgs.dos2unix}/bin/unix2dos < ${
      pkgs.writeText "install.bat.lf" ''
        @echo off
        setlocal

        rem ── RDP host + RemoteApp ────────────────────────────────────────────
        rem fDenyTSConnections: accept incoming RDP at all.
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

        rem fDisabledAllowList: let an *arbitrary* executable be published as a
        rem RemoteApp. Without this every `winapps <app>` fails, and it fails
        rem looking like a connection problem rather than a permissions one.
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList" /v fDisabledAllowList /t REG_DWORD /d 1 /f

        netsh advfirewall firewall set rule group="remote desktop" new enable=Yes

        rem ── Office 365 ──────────────────────────────────────────────────────
        rem officecdn.microsoft.com/pr/wsus/setup.exe is Microsoft's evergreen
        rem Office Deployment Tool: always current, no version to pin and go
        rem stale. %~dp0 is this script's own directory, i.e. the copied /oem.
        mkdir C:\OfficeSetup
        powershell -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; Invoke-WebRequest -Uri 'https://officecdn.microsoft.com/pr/wsus/setup.exe' -OutFile 'C:\OfficeSetup\setup.exe'"

        if not exist C:\OfficeSetup\setup.exe (
          echo Office Deployment Tool download failed. > C:\OfficeSetup\FAILED.txt
          exit /b 1
        )

        C:\OfficeSetup\setup.exe /configure "%~dp0configuration.xml"

        endlocal
      ''
    } > $out
  '';
in
{
  config = lib.mkIf cfg.enable {
    # C+ copies and replaces: the OEM directory is a plain bind mount into the
    # container, and a symlink into /nix/store would not resolve from inside it.
    # Replacing on every activation means editing the script above and
    # rebuilding is enough — no stale copy to notice later.
    systemd.tmpfiles.rules = [
      "C+ ${cfg.stateDir}/oem/install.bat 0644 root root - ${installBat}"
      "C+ ${cfg.stateDir}/oem/configuration.xml 0644 root root - ${officeConfig}"
    ];
  };
}
```

- [ ] **Step 3: Run the check again**

```bash
nix eval --raw .#nixosConfigurations.omnibook.config.systemd.tmpfiles.rules --apply 'rs: builtins.concatStringsSep "\n" rs' | grep install.bat
```

Expected: a line beginning `C+ /var/lib/winapps/oem/install.bat`. It will show nothing until Task 7 enables the module on this host — if so, temporarily set `services.winapps.enable = true;` in `hosts/omnibook/default.nix` to run the check, and revert.

- [ ] **Step 4: Inspect the generated batch file by hand**

```bash
cat "$(nix eval --raw .#nixosConfigurations.omnibook.config.systemd.tmpfiles.rules --apply 'rs: builtins.head (builtins.filter (r: builtins.match ".*install.bat.*" r != null) rs)' | awk '{print $NF}')"
```

Expected: the batch file, with the three `reg add` / `netsh` lines and the Office download. Confirm by eye that no line was mangled by Nix string interpolation — `%~dp0` in particular must be intact.

- [ ] **Step 5: Commit**

```bash
nix fmt
git add modules/services/winapps/oem.nix
git commit -m "feat(winapps): first-boot RemoteApp registry setup and Office 365 install"
```

---

### Task 5: Desktop integration — winapps.conf, launchers, app definitions

**Files:**
- Create: `modules/services/winapps/home.nix`

**Interfaces:**
- Consumes: `config.services.winapps.{enable,apps,sharedDir}` (Task 3), `config.sops.secrets.winapps_vm_env.path` (Task 2), `inputs.winapps` (Task 1).
- Produces: `~/.config/winapps/winapps.conf`, `~/.local/share/winapps/apps`, one `~/.local/share/applications/winapps-<id>.desktop` per app plus `winapps-windows.desktop`, and `winapps` on `PATH`.

Three findings from reading the WinApps source that this task depends on, and which are not obvious:

1. `winapps <id>` resolves the id by sourcing `<script dir>/../apps/<id>/info`, then `~/.local/share/winapps/apps/<id>/info`, then `/usr/local/share/winapps/...` (`src/bin/winapps:841-852`). The Nix package puts its definitions in `$out/src/apps`, not `$out/apps`, so the first path never matches. **The `~/.local/share/winapps/apps` link is required**, not a nicety — without it every launch dies with "unsupported app".
2. `WAFLAVOR="manual"` short-circuits all container management (`src/bin/winapps:935`). Any other value makes WinApps inspect, start and stop the container itself, fighting systemd for the same resource.
3. `DEBUG` defaults to `"true"` (`src/bin/winapps:57`), which writes a log on every launch. Set it off explicitly.

- [ ] **Step 1: Write the failing check**

```bash
nix eval --raw .#nixosConfigurations.omnibook.config.home-manager.users.otis.home.packages --apply 'ps: builtins.concatStringsSep " " (map (p: p.name) ps)' | grep winapps
```

Expected: FAIL (no match).

- [ ] **Step 2: Create the module**

Create `modules/services/winapps/home.nix`:

```nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.winapps;

  winappsPkg = inputs.winapps.packages.${pkgs.stdenv.hostPlatform.system}.winapps;

  appIds = map (a: a.id) cfg.apps;

  # WinApps ships one directory per supported application, each with an `info`
  # file (a shell fragment defining NAME, FULL_NAME, WIN_EXECUTABLE, CATEGORIES,
  # MIME_TYPES). Upstream's setup.sh reads those at *install* time, probing a
  # running VM and writing into ~/.local behind home-manager's back. Reading
  # them at *build* time instead means the launchers exist after a rebuild
  # whether or not the VM has ever booted, and a bad app id fails the build
  # rather than producing a launcher that silently does nothing.
  desktopEntries = pkgs.runCommand "winapps-desktop-entries" { } ''
    mkdir -p "$out"

    for id in ${lib.escapeShellArgs appIds}; do
      info="${winappsPkg}/src/apps/$id/info"
      if [ ! -f "$info" ]; then
        echo "winapps: no such application id '$id'" >&2
        echo "available:" >&2
        ls "${winappsPkg}/src/apps" >&2
        exit 1
      fi

      NAME=""; FULL_NAME=""; CATEGORIES=""; MIME_TYPES=""
      # shellcheck disable=SC1090
      . "$info"

      {
        echo "[Desktop Entry]"
        echo "Type=Application"
        echo "Name=$NAME"
        echo "Comment=$FULL_NAME"
        echo "Exec=${winappsPkg}/bin/winapps $id %F"
        echo "Icon=${winappsPkg}/src/apps/$id/icon.svg"
        echo "Terminal=false"
        # FreeRDP sets the RemoteApp window's class from the Windows-side
        # application name, so this is what lets niri match the window to this
        # entry (and what makes the taskbar icon correct).
        echo "StartupWMClass=$FULL_NAME"
        echo "Categories=''${CATEGORIES:-WinApps}"
        echo "MimeType=''${MIME_TYPES:-}"
      } > "$out/$id.desktop"
    done

    # The full remote desktop, for the rare thing with no launcher of its own.
    {
      echo "[Desktop Entry]"
      echo "Type=Application"
      echo "Name=Windows"
      echo "Comment=Full Windows desktop over RDP"
      echo "Exec=${winappsPkg}/bin/winapps windows"
      echo "Icon=${winappsPkg}/src/install/windows.svg"
      echo "Terminal=false"
      echo "StartupWMClass=Microsoft Windows"
      echo "Categories=WinApps"
    } > "$out/windows.desktop"
  '';

  # winapps.conf is a plain shell file the launcher sources, and it has to carry
  # the RDP password — so it cannot be a store file. Written at activation
  # instead, as root (which can read the sops secret regardless of owner), then
  # handed to the user 0600.
  #
  # This runs as a *system* activation script rather than a home-manager one so
  # it can be ordered after sops-nix's `setupSecrets`; home-manager activation
  # has no such ordering guarantee, and on a fresh boot would read a secret that
  # is not decrypted yet.
  writeConf = pkgs.writeShellScript "winapps-write-conf" ''
    set -eu
    secret=${config.sops.secrets.winapps_vm_env.path}
    dir=/home/otis/.config/winapps
    conf="$dir/winapps.conf"

    user=$(${pkgs.gnused}/bin/sed -n 's/^USERNAME=//p' "$secret")
    pass=$(${pkgs.gnused}/bin/sed -n 's/^PASSWORD=//p' "$secret")

    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    ${pkgs.coreutils}/bin/cat > "$conf" <<EOF
    RDP_USER="$user"
    RDP_PASS="$pass"
    RDP_DOMAIN=""
    RDP_IP="127.0.0.1"
    RDP_SCALE=100
    WAFLAVOR="manual"
    AUTOPAUSE="off"
    DEBUG="false"
    EOF

    ${pkgs.coreutils}/bin/chown otis:users "$dir" "$conf"
    ${pkgs.coreutils}/bin/chmod 0700 "$dir"
    ${pkgs.coreutils}/bin/chmod 0600 "$conf"
  '';
in
{
  config = lib.mkIf cfg.enable {
    system.activationScripts.winappsConf = {
      deps = [ "setupSecrets" ];
      text = "${writeConf}";
    };

    home.extraOptions = {
      home.packages = [ winappsPkg ];

      xdg.dataFile =
        lib.listToAttrs (
          map (
            id:
            lib.nameValuePair "applications/winapps-${id}.desktop" {
              source = "${desktopEntries}/${id}.desktop";
            }
          ) (appIds ++ [ "windows" ])
        )
        // {
          # Required, not decorative: `winapps <id>` looks for the app
          # definition here. The package keeps its copy under src/apps, which is
          # not on any path the launcher searches. See src/bin/winapps:841-852.
          "winapps/apps".source = "${winappsPkg}/src/apps";
        };
    };
  };
}
```

- [ ] **Step 3: Temporarily enable the module so the checks have something to see**

In `hosts/omnibook/default.nix`, in the block after `services.rclone`, add:

```nix
  services.winapps.enable = true;
```

(Task 7 makes this permanent and adds the gamingpc side. It is added here only so the following steps can evaluate.)

- [ ] **Step 4: Run the check again**

```bash
nix eval --raw .#nixosConfigurations.omnibook.config.home-manager.users.otis.home.packages --apply 'ps: builtins.concatStringsSep " " (map (p: p.name) ps)' | grep -o 'winapps[^ ]*'
```

Expected: a `winapps-0-unstable-...` entry.

- [ ] **Step 5: Build the desktop entries and read one**

```bash
nix build --no-link --print-out-paths .#nixosConfigurations.omnibook.config.home-manager.users.otis.xdg.dataFile."applications/winapps-word-o365.desktop".source
cat "$(nix build --no-link --print-out-paths .#nixosConfigurations.omnibook.config.home-manager.users.otis.xdg.dataFile.\"applications/winapps-word-o365.desktop\".source)"
```

Expected: a valid desktop entry with `Name=Word`, `Exec=/nix/store/...-winapps.../bin/winapps word-o365 %F`, and a populated `MimeType=` line containing `application/vnd.openxmlformats-officedocument.wordprocessingml.document`.

If the build instead fails with `winapps: no such application id`, the id list in Task 3 is wrong — that error is the check doing its job.

- [ ] **Step 6: Confirm evaluation is clean**

```bash
just check
```

Expected: passes.

- [ ] **Step 7: Commit**

```bash
nix fmt
git add modules/services/winapps/home.nix hosts/omnibook/default.nix
git commit -m "feat(winapps): generated launchers, app definitions and winapps.conf"
```

---

### Task 6: DMS — status widget and dankMenu controls

**Files:**
- Modify: `modules/desktop/dms/plugins.nix`

**Interfaces:**
- Consumes: `config.services.winapps.{enable,apps,sharedDir}` (Task 3).
- Produces: the `windows` dankMenu subtree and the `dockerManager` bar widget.

`dockerManager` is `luckshiba-docker-manager` in `dms-plugin-registry`, so it needs no `src` — just `enable` and settings, like the other registry plugins in this file.

The plugin cannot provide *start*. NixOS runs oci-containers with `--rm`, so a stopped container is a deleted container and its start button has nothing to act on. That is a consequence of the container being recreated from the unit each time, which is what makes it declarative — so start lives in dankMenu instead.

- [ ] **Step 1: Write the failing check**

```bash
nix eval --raw .#nixosConfigurations.omnibook.config.home-manager.users.otis.programs.dank-material-shell.plugins.dankMenu.settings.menuPath \
  | xargs cat | grep -c 'windows\.'
```

Expected: `0`.

- [ ] **Step 2: Add the plugin**

In `modules/desktop/dms/plugins.nix`, in the `programs.dank-material-shell.plugins` attrset, after the `usbManager.enable` line:

```nix
        # LuckShiba/DmsDockerManager, via dms-plugin-registry. The status half
        # of the Windows VM controls: running/stopped, ports, logs, stop and
        # restart. It cannot *start* the VM — NixOS runs oci-containers with
        # `--rm`, so a stopped container no longer exists for the plugin's start
        # button to act on. Start lives in the dankMenu `windows` subtree below.
        dockerManager = {
          enable = true;
          settings = {
            # the plugin defaults to `alacritty --hold`, which is not installed here.
            terminalApplication = "ghostty -e";
          };
        };
```

- [ ] **Step 3: Add the menu rows**

Still in `modules/desktop/dms/plugins.nix`, in the `let` block, after the `flakeDir` definition:

```nix
  winappsCfg = config.services.winapps;
```

Then in `dankMenuRows`, add the root row directly after the `trigger` root row:

```nix
    {
      id = "windows";
      icon = "desktop_windows";
      label = "Windows";
      aliases = [
        "office"
        "word"
        "excel"
        "vm"
      ];
      # The whole subtree disappears on a host without the VM, rather than
      # offering rows that would fail.
      when = if winappsCfg.enable then "true" else "false";
    }
```

and the subtree itself after the Trigger section, before the Style section:

```nix
    # Windows — the VM is deliberately not running most of the time, so the
    # first two rows are the primary lifecycle controls. `disabled` is a shell
    # snippet the plugin evaluates while this submenu is open, so each row
    # greys out when it would be a no-op.
    {
      id = "windows.start";
      icon = "play_arrow";
      label = "Start VM";
      aliases = [ "boot" ];
      disabled = "systemctl is-active --quiet docker-windows";
      action = "systemctl start docker-windows";
    }
    {
      id = "windows.stop";
      icon = "stop";
      label = "Stop VM";
      aliases = [ "shutdown" ];
      disabled = "! systemctl is-active --quiet docker-windows";
      # Windows gets 120s to shut down cleanly (see ../../services/winapps),
      # so this row can take a while to complete. It does not block the menu.
      action = "systemctl stop docker-windows";
    }
  ]
  ++ map (app: {
    id = "windows.${app.id}";
    icon = app.icon;
    label = app.label;
    # Launching while the VM is down fails with a desktop notification rather
    # than silently, so these are not disabled — starting the VM first is a
    # reasonable thing to forget, and the error says so.
    action = "winapps ${app.id}";
  }) winappsCfg.apps
  ++ [
    {
      id = "windows.desktop";
      icon = "desktop_windows";
      label = "Full Desktop";
      action = "winapps windows";
    }
    {
      id = "windows.viewer";
      icon = "monitor";
      label = "Install Viewer";
      aliases = [ "console" ];
      # The only way to watch the 20-40 minute first boot.
      target = "http://127.0.0.1:8006";
    }
    {
      id = "windows.shared";
      icon = "folder_shared";
      label = "Shared Folder";
      # Appears inside Windows as \\host.lan\Data.
      action = "nautilus ${winappsCfg.sharedDir}";
    }
```

The `dankMenuRows` list is currently one `[ ... ]` literal; splicing `map` into it means breaking it into `[ ... ] ++ map (...) ... ++ [ ... ]` as shown. Keep the ordering — the plugin's parser reads declaration order, and a menu whose rows shuffle alphabetically is the bug this list was written as a list to avoid.

- [ ] **Step 4: Run the check again**

```bash
nix eval --raw .#nixosConfigurations.omnibook.config.home-manager.users.otis.programs.dank-material-shell.plugins.dankMenu.settings.menuPath \
  | xargs cat | grep -c 'windows\.'
```

Expected: `9` — start, stop, five applications, full desktop, viewer, shared folder. Adjust if `services.winapps.apps` was changed.

- [ ] **Step 5: Verify the generated JSONC is valid and ordered**

```bash
nix eval --raw .#nixosConfigurations.omnibook.config.home-manager.users.otis.programs.dank-material-shell.plugins.dankMenu.settings.menuPath \
  | xargs cat | grep -n 'windows'
```

Expected: the `"windows"` root row appears before every `"windows.*"` row, and `windows.start` before `windows.stop`.

- [ ] **Step 6: Commit**

```bash
nix fmt
git add modules/desktop/dms/plugins.nix
git commit -m "feat(dms): dockerManager widget and a windows subtree in dankMenu"
```

---

### Task 7: Enable on both hosts, verify, document

**Files:**
- Modify: `hosts/omnibook/default.nix`
- Modify: `hosts/gamingpc/default.nix`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the failing check — the constraint that matters most**

The single requirement most likely to regress is "nothing runs at boot". Check it directly:

```bash
nix eval .#nixosConfigurations.omnibook.config.systemd.units."docker-windows.service".wantedBy
```

Expected right now: FAIL or `[ ]` — and after this task it must still be `[ ]`. If it ever contains `"multi-user.target"`, `autoStart` has been flipped somewhere and the VM will boot with the machine.

- [ ] **Step 2: Finalise the omnibook host**

In `hosts/omnibook/default.nix`, replace the bare `services.winapps.enable = true;` added in Task 5 with the commented block, placed after the `services.rclone` block:

```nix
  # On-demand Windows VM for Office (see modules/services/winapps). Not started
  # at boot by design — start it from dankMenu's Windows submenu. Defaults are
  # sized for this laptop; the VM is a real battery cost while running.
  services.winapps.enable = true;
```

- [ ] **Step 3: Enable it on gamingpc with more headroom**

In `hosts/gamingpc/default.nix`, after the `services.rclone` block:

```nix
  # On-demand Windows VM for Office (see modules/services/winapps). Same VM as
  # on omnibook, given the headroom this machine has and the laptop does not.
  services.winapps = {
    enable = true;
    ram = "8G";
    cores = 6;
  };
```

- [ ] **Step 4: Verify both hosts evaluate and the boot constraint holds**

```bash
just check
nix eval .#nixosConfigurations.omnibook.config.systemd.units."docker-windows.service".wantedBy
nix eval .#nixosConfigurations.gamingpc.config.systemd.units."docker-windows.service".wantedBy
nix eval .#nixosConfigurations.gamingpc.config.services.winapps.ram
```

Expected: `just check` passes, both `wantedBy` are `[ ]`, and gamingpc's ram is `"8G"`.

- [ ] **Step 5: Verify the ports are loopback-only**

```bash
nix eval --raw .#nixosConfigurations.omnibook.config.virtualisation.oci-containers.containers.windows.ports \
  --apply 'ps: builtins.concatStringsSep "\n" ps'
```

Expected: three lines, every one starting `127.0.0.1:`. A line without that prefix is a live RDP host on every network the laptop joins — treat it as a blocker, not a nit.

- [ ] **Step 6: Dry build both hosts**

```bash
just drybuild omnibook
just drybuild gamingpc
```

Expected: both succeed.

- [ ] **Step 7: Commit the configuration**

```bash
nix fmt
git add hosts/omnibook/default.nix hosts/gamingpc/default.nix
git commit -m "feat(hosts): enable the on-demand Windows VM on both machines"
```

- [ ] **Step 8: Real rebuild and first boot — user-facing, do not automate**

Hand back to the user with these instructions:

```bash
just rebuild
```

Then, from dankMenu (`Mod+Space`) → Windows → Start VM, or:

```bash
systemctl start docker-windows
```

The first start pulls the `dockurr/windows` image, downloads a Windows ISO, runs an unattended install, and then downloads and installs Office. Budget 20 to 40 minutes. Watch it at <http://127.0.0.1:8006>.

When Windows reaches the desktop and Office has installed, open Word once inside that viewer and sign in with the Microsoft 365 account. The activation persists in `/var/lib/winapps/storage`.

Then, back on Linux:

```bash
winapps word-o365
```

- [ ] **Step 9: Verify the polkit grant is as narrow as intended**

After the rebuild, as the user (not root):

```bash
systemctl start docker-windows    # must not prompt
systemctl stop docker-windows     # must not prompt
systemctl restart docker.service  # MUST prompt — the grant does not cover this
```

If the third command does not prompt, the polkit rule is broader than written and needs revisiting before this ships.

- [ ] **Step 10: Document it**

Add this section to `README.md`, alongside the other feature sections and matching their heading level:

```markdown
### Windows apps (WinApps)

Microsoft Office runs in a Windows VM and shows up as ordinary windows — Word is
a launcher entry, `.docx` opens in it, and there is no second desktop to alt-tab
into. `modules/services/winapps/` holds the whole thing.

**The VM does not run at boot.** That is deliberate: it costs ~4 GB of RAM and a
steady slice of CPU, which on the laptop is a battery bill for something used a
few times a week. Start it from `Mod+Space` → Windows → Start VM, or:

```
systemctl start docker-windows
```

The bar's Docker widget shows whether it is up. It can stop and restart the VM
but not start it — NixOS runs the container with `--rm`, so a stopped container
no longer exists for that button to act on. Start from the menu.

**First boot takes 20–40 minutes** and is unattended: Windows installs itself,
then Office 365 installs from Microsoft's Deployment Tool. Watch it at
<http://127.0.0.1:8006>. When it settles, open Word inside that viewer once and
sign in with your Microsoft 365 account — the activation lives in the VM's disk
at `/var/lib/winapps/storage` and survives restarts.

If Office is missing afterwards, look for `C:\OfficeSetup\FAILED.txt` in the
guest; `C:\OEM\install.bat` is re-runnable by hand.

**Shared folder:** `~/Windows` on this side, `\\host.lan\Data` on the Windows
side.

**Adding an application** — add it to `services.winapps.apps` in the host file.
The `id` must name a directory in WinApps' own list:

```
ls "$(nix build --no-link --print-out-paths 'github:winapps-org/winapps#winapps')/src/apps"
```

A wrong id fails the build rather than producing a launcher that does nothing.
Both a desktop entry and a dankMenu row come from the same list, so they cannot
drift apart.

**Ports are loopback-only** (`127.0.0.1:3389` and `127.0.0.1:8006`). Do not drop
those prefixes — the VM has an RDP host with a fixed password, and Docker's
default would publish it on every network the laptop joins.
```

- [ ] **Step 11: Commit**

```bash
git add README.md
git commit -m "docs(readme): document the on-demand Windows VM"
```

---

## Known risks

Recorded because they will not surface until the first real boot, and each looks like a different problem than it is.

- **`C+` tmpfiles entries** require a reasonably recent systemd. If `install.bat` does not appear under `/var/lib/winapps/oem` after a rebuild, check `systemd-tmpfiles --create` output before suspecting the container.
- **The `setupSecrets` activation dependency** in Task 5 is the ordering that makes `winapps.conf` correct on a cold boot. If `RDP_PASS` ever comes out empty, that dependency is the first thing to check.
- **Office install failure** leaves `C:\OfficeSetup\FAILED.txt` in the guest and no Office. It is re-runnable by hand from inside the VM; it is deliberately not retried automatically, because a retry loop around a 40-minute download hides more than it fixes.
- **`dockurr/windows` fetches Windows from Microsoft.** A change on their side breaks first boot for everyone using the image, not just this config — check the image's issue tracker before debugging locally.
