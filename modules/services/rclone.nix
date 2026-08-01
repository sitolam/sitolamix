{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.rclone;

  # NixOS ships fusermount only as a setuid wrapper, and rclone shells out to it
  # to unmount itself when the unit stops.
  wrappers = "/run/wrappers/bin";

  # A mount left behind by a crash makes its directory unusable ("Transport
  # endpoint is not connected") and rclone then refuses to mount over it.
  prepare = pkgs.writeShellScript "rclone-mount-prepare" ''
    mp="$1"
    if [ -e "$mp" ] && ! ${pkgs.coreutils}/bin/ls "$mp" >/dev/null 2>&1; then
      ${wrappers}/fusermount3 -uz "$mp" 2>/dev/null ||
        ${wrappers}/fusermount -uz "$mp" 2>/dev/null || true
    fi
    ${pkgs.coreutils}/bin/mkdir -p "$mp"
  '';

  serviceName = name: "rclone-${name}";
  units = map (name: "${serviceName name}.service") (lib.attrNames cfg.remotes);

  rclone-mounts = pkgs.writeShellScriptBin "rclone-mounts" ''
    set -u
    units="${lib.concatStringsSep " " units}"
    if [ -z "$units" ]; then
      echo "rclone-mounts: no remotes declared (services.rclone.remotes is empty)" >&2
      exit 1
    fi
    case "''${1:-status}" in
      status) systemctl --user --no-pager status $units ;;
      start) systemctl --user start $units ;;
      stop) systemctl --user stop $units ;;
      restart) systemctl --user restart $units ;;
      logs) journalctl --user -f ${lib.concatMapStringsSep " " (u: "-u ${u}") units} ;;
      *)
        echo "usage: rclone-mounts [status|start|stop|restart|logs]" >&2
        exit 1
        ;;
    esac
  '';

  # muscle memory from quickhyprnix.
  reload-rclone = pkgs.writeShellScriptBin "reload-rclone" ''
    exec ${rclone-mounts}/bin/rclone-mounts restart
  '';
in
{
  options.services.rclone = {
    enable = lib.mkEnableOption "rclone cloud mounts (one systemd user service per remote)";

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "%h/.config/rclone/rclone.conf";
      description = ''
        Where rclone's config lives. Written imperatively by `rclone config` and
        kept out of the repo — it holds live OAuth refresh tokens. systemd
        specifiers (`%h`) are expanded.
      '';
    };

    mountBase = lib.mkOption {
      type = lib.types.str;
      default = "%h/Cloud";
      description = "Directory every remote is mounted under by default.";
    };

    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--vfs-cache-mode=full"
        "--vfs-cache-max-size=5G"
        "--vfs-cache-max-age=24h"
        "--dir-cache-time=1000h"
        "--poll-interval=15s"
        "--log-level=INFO"
      ];
      description = ''
        Flags passed to every mount. The very long directory cache is safe
        because `--poll-interval` makes rclone pick up changes made elsewhere
        within seconds (Google Drive supports change polling).
      '';
    };

    remotes = lib.mkOption {
      default = { };
      example = {
        gdrive_personal = { };
        work = {
          remote = "work:Projects";
          extraFlags = [ "--read-only" ];
        };
      };
      description = ''
        Remotes to mount, keyed by the name they have in rclone's config (see
        `rclone listremotes`). Each one gets its own `rclone-<name>.service`
        user unit.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              remote = lib.mkOption {
                type = lib.types.str;
                default = "${name}:";
                description = "Remote path to mount — a whole drive (`name:`) or a subfolder (`name:Sub/Dir`).";
              };

              mountPoint = lib.mkOption {
                type = lib.types.str;
                default = "${cfg.mountBase}/${name}";
                description = "Where to mount it. Created if it doesn't exist.";
              };

              extraFlags = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Extra rclone flags for this remote only.";
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
    home.extraOptions = {
      home.packages = [
        pkgs.rclone
        rclone-mounts
        reload-rclone
      ];

      systemd.user.services = lib.mapAttrs' (
        name: remote:
        lib.nameValuePair (serviceName name) {
          Unit = {
            Description = "rclone mount ${remote.remote} at ${remote.mountPoint}";
            Documentation = "https://rclone.org/commands/rclone_mount/";
            After = [ "network-online.target" ];
            # skip (rather than fail) on a machine where `rclone config` hasn't run yet.
            ConditionPathExists = cfg.configFile;
            StartLimitIntervalSec = 600;
            StartLimitBurst = 10;
          };

          Service = {
            # rclone signals readiness once the mount is actually usable, so a
            # `systemctl start` that returns has really mounted the remote.
            Type = "notify";
            Environment = [ "PATH=${wrappers}" ];
            ExecStartPre = ''${prepare} "${remote.mountPoint}"'';
            ExecStart = lib.concatStringsSep " " (
              [
                "${pkgs.rclone}/bin/rclone mount"
                "--config=${cfg.configFile}"
              ]
              ++ cfg.flags
              ++ remote.extraFlags
              ++ [
                ''"${remote.remote}"''
                ''"${remote.mountPoint}"''
              ]
            );
            # rclone unmounts itself on SIGTERM — this only cleans up after a crash.
            ExecStopPost = ''-${wrappers}/fusermount3 -uz "${remote.mountPoint}"'';
            Restart = "on-failure";
            RestartSec = 10;
          };

          # not graphical-session.target: the mount should survive a compositor
          # restart and work in a plain TTY session too.
          Install.WantedBy = [ "default.target" ];
        }
      ) cfg.remotes;
    };
  };
}
