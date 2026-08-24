default:
    @just --list

fmt:
    nix fmt

check:
    nix flake check --no-build

drybuild host=`hostname`:
    nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel --dry-run

build host=`hostname`:
    nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel

rebuild:
    nh os switch .

update:
    nix flake update
    just rebuild

diff:
    nvd diff /run/current-system result

doctor:
    just check
    just drybuild

outputs:
    niri msg outputs

windows:
    niri msg windows

dms-reload:
    systemctl --user restart dms.service

# edit an encrypted secret, e.g. `just secret secrets/nas.yaml`
secret file:
    #!/usr/bin/env bash
    set -euo pipefail
    # sops only searches *user* key locations, so hand it this machine's SSH
    # host key (root-only, hence the sudo) converted to age. Passed per-command,
    # never exported into the shell.
    sudo -v
    SOPS_AGE_KEY="$(sudo cat /etc/ssh/ssh_host_ed25519_key | nix run nixpkgs#ssh-to-age -- -private-key)" \
        nix run nixpkgs#sops -- {{file}}

# re-encrypt a secret to the recipients in .sops.yaml (after adding a host)
updatekeys file:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo -v
    SOPS_AGE_KEY="$(sudo cat /etc/ssh/ssh_host_ed25519_key | nix run nixpkgs#ssh-to-age -- -private-key)" \
        nix run nixpkgs#sops -- updatekeys {{file}}
