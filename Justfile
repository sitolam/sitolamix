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

noctalia-reload:
    systemctl --user restart noctalia.service
