{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.services.nas;

  credentials = config.sops.secrets.nas_credentials.path;

  mountPoints = map (share: "${cfg.mountRoot}/${share}") cfg.shares;
  mountUnits = map (path: "${utils.escapeSystemdPath path}.mount") mountPoints;
  automountUnits = map (path: "${utils.escapeSystemdPath path}.automount") mountPoints;

  # A CIFS session left over from before a suspend or a network switch is
  # dead, and every stat on it (Nautilus checks all mounts at startup) hangs
  # until the kernel gives up on the server. So mount only while the NAS
  # answers on 445, and otherwise drop the shares and their automounts.
  # `release` is lazy and forced so it never waits on the dead server.
  nasSync = pkgs.writeShellScript "nas-sync" ''
    release() {
      for mp in ${lib.escapeShellArgs mountPoints}; do
        if ${pkgs.util-linux}/bin/findmnt -n -t cifs "$mp" >/dev/null; then
          ${pkgs.util-linux}/bin/umount -f -l "$mp"
        fi
      done
      ${pkgs.systemd}/bin/systemctl stop --no-block ${
        lib.escapeShellArgs (automountUnits ++ mountUnits)
      }
    }
    case "$1" in
      release) release ;;
      check)
        if ${pkgs.coreutils}/bin/timeout 2 ${pkgs.bash}/bin/bash -c ': </dev/tcp/$0/445' ${lib.escapeShellArg cfg.server} 2>/dev/null; then
          ${pkgs.systemd}/bin/systemctl start --no-block ${
            lib.escapeShellArgs (automountUnits ++ mountUnits)
          }
        else
          release
        fi ;;
    esac
  '';

  # noauto keeps the shares out of the boot transaction — the laptop is often
  # away from the home LAN, and a boot-time mount would stall/fail there.
  # Mounting instead happens from the NetworkManager dispatcher below;
  # x-systemd.automount remounts on access in between, while the NAS answers. x-gvfs-show lists the share in the Nautilus sidebar; no
  # idle-timeout, since it should stay mounted while the network is up.
  # echo_interval=10: a server that stops answering is dropped after 30 s
  # (3 missed echoes) instead of the default 180 s.
  mountOptions = share: [
    "credentials=${credentials}"
    "uid=1000"
    "gid=100"
    "file_mode=0644"
    "dir_mode=0755"
    "iocharset=utf8"
    "echo_interval=10"
    "nofail"
    "_netdev"
    "noauto"
    "x-systemd.automount"
    "x-systemd.mount-timeout=10s"
    "x-gvfs-show"
    "x-gvfs-name=${share}"
  ];

  mount = share: {
    name = "${cfg.mountRoot}/${share}";
    value = {
      device = "//${cfg.server}/${share}";
      fsType = "cifs";
      options = mountOptions share;
    };
  };
in
{
  options.services.nas = {
    enable = lib.mkEnableOption "SMB shares from the home NAS";

    server = lib.mkOption {
      type = lib.types.str;
      description = "Host or IP serving the SMB shares.";
    };

    shares = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Share names to mount under `mountRoot`.";
    };

    mountRoot = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/nas";
      description = "Directory the shares are mounted under.";
    };
  };

  config = lib.mkIf cfg.enable {
    # mount.cifs reads the password from the sops-decrypted file in
    # /run/secrets (tmpfs, root-only) — never the nix store.
    sops.secrets.nas_credentials = {
      sopsFile = ../../secrets/nas.yaml;
      mode = "0400";
    };

    fileSystems = lib.listToAttrs (map mount cfg.shares);

    # Re-check on every connection change: a switch to another network
    # fires these too, not only a full disconnect.
    networking.networkmanager.dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeShellScript "nas-mount" ''
          case "$2" in
            up | down | vpn-up | vpn-down | connectivity-change | dhcp4-change)
              ${nasSync} check ;;
          esac
        '';
      }
    ];

    # Drop the shares before suspend/hibernate; NetworkManager's `up` on
    # resume mounts them again.
    systemd.services.nas-release-before-sleep = {
      description = "Unmount NAS shares before sleep";
      before = [ "sleep.target" ];
      wantedBy = [ "sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${nasSync} release";
      };
    };
  };
}
