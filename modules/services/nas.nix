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

  # noauto keeps the shares out of the boot transaction — the laptop is often
  # away from the home LAN, and a boot-time mount would stall/fail there.
  # Mounting instead happens from the NetworkManager dispatcher below;
  # x-systemd.automount is the fallback if that attempt missed the NAS still
  # booting. x-gvfs-show lists the share in the Nautilus sidebar; no
  # idle-timeout, since it should stay mounted while the network is up.
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
    # mount.cifs reads the password from the sops-decrypted file in
    # /run/secrets (tmpfs, root-only) — never the nix store.
    sops.secrets.nas_credentials = {
      sopsFile = ../../secrets/nas.yaml;
      mode = "0400";
    };

    fileSystems = lib.listToAttrs (map mount cfg.shares);

    # Mount on any connection-up, release once NetworkManager reports fully
    # disconnected (not just this connection down — toggling the WireGuard
    # tunnel also fires `down` while Wi-Fi stays up). --no-block: the
    # dispatcher must not wait on the NAS.
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
