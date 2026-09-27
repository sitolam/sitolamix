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

  # noauto keeps the shares out of the boot transaction: the NAS is on the
  # home LAN and this flake also runs on a laptop, so a boot-time mount would
  # stall boot (and fail) whenever the machine is elsewhere. Mounting happens
  # instead from the NetworkManager dispatcher below, as soon as a connection
  # comes up. x-systemd.automount stays as the fallback: if the dispatcher's
  # attempt failed (NAS still booting, say), touching the path retries it.
  #
  # x-gvfs-show makes GVFS's udisks2 volume monitor list the share in the
  # Nautilus sidebar as a mounted drive (it handles `//host/share` fstab
  # entries too, not only block devices). No idle-timeout: the shares should
  # stay mounted while the network is up, not drop out of the sidebar after
  # ten idle minutes.
  mountOptions = share: [
    "credentials=${credentials}"
    "uid=1000"
    "gid=100"
    "file_mode=0644"
    "dir_mode=0755"
    "iocharset=utf8"
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
    # The share password never reaches the nix store: mount.cifs reads it from
    # the sops-decrypted file in /run/secrets (tmpfs, root-only). See the README
    # for the key this file holds.
    sops.secrets.nas_credentials = {
      sopsFile = ../../secrets/nas.yaml;
      mode = "0400";
    };

    fileSystems = lib.listToAttrs (map mount cfg.shares);

    # Mount the shares whenever a connection comes up, and release them once
    # the machine has no connection left, so a vanished NAS never leaves a hung
    # mountpoint. The "disconnected" check matters: toggling the WireGuard
    # tunnel (services.wireguard-laxoi) also fires `down` while Wi-Fi stays up.
    # Away from home the start just fails after mount-timeout and is retried on
    # the next connection change. --no-block: the dispatcher must not wait on
    # the NAS.
    networking.networkmanager.dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeShellScript "nas-mount" ''
          case "$2" in
            up | vpn-up | connectivity-change)
              ${pkgs.systemd}/bin/systemctl start --no-block ${lib.escapeShellArgs mountUnits} ;;
            down)
              if [ "$(${pkgs.networkmanager}/bin/nmcli -t -f STATE general)" = disconnected ]; then
                ${pkgs.systemd}/bin/systemctl stop --no-block ${lib.escapeShellArgs mountUnits}
              fi ;;
          esac
        '';
      }
    ];
  };
}
