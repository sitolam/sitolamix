{ config, lib, ... }:
let
  cfg = config.services.nas;

  credentials = config.sops.secrets.nas_credentials.path;

  # noauto + x-systemd.automount: systemd creates an .automount unit and only
  # runs mount.cifs on first access to the path. The NAS is on the home LAN and
  # this flake also runs on a laptop, so a boot-time mount would stall boot
  # (and fail) whenever the machine is elsewhere. idle-timeout unmounts again
  # after 10 min so a share that went away does not leave a hung mountpoint.
  mountOptions = [
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
    "x-systemd.idle-timeout=600"
    "x-systemd.mount-timeout=10s"
  ];

  mount = share: {
    name = "${cfg.mountRoot}/${share}";
    value = {
      device = "//${cfg.server}/${share}";
      fsType = "cifs";
      options = mountOptions;
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

    # Nautilus sidebar entries. The mounts are otherwise invisible in the file
    # manager: gio only auto-displays mounts under /media, /run/media/$USER or
    # $HOME, and the fstab flag that would force it (`x-gvfs-show`) is only read
    # by GVFS's udisks2 monitor, which handles block devices — not `//host/share`.
    # A bookmark also works while the share is idle-unmounted: opening it just
    # touches the path, which is what triggers the automount.
    home.extraOptions.gtk.gtk3.bookmarks = map (
      share: "file://${cfg.mountRoot}/${share} ${share}"
    ) cfg.shares;
  };
}
