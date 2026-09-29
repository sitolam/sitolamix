{
  config,
  lib,
  ...
}:
let
  cfg = config.services.winapps;
in
{
  options.services.winapps = {
    enable = lib.mkEnableOption ''
      an on-demand Windows VM (dockurr/windows) whose applications launch as
      native windows over RDP. Not started at boot
    '';

    version = lib.mkOption {
      type = lib.types.str;
      default = "11l";
      description = ''
        dockurr/windows VERSION. `11l` (Windows 11 IoT Enterprise LTSC) is the
        smallest image that still ships an RDP host — Home editions can only
        act as RDP clients.
      '';
    };

    ram = lib.mkOption {
      type = lib.types.str;
      default = "4G";
      description = "RAM handed to the guest. 4G is the floor for Windows 11 plus Office.";
    };

    disk = lib.mkOption {
      type = lib.types.str;
      default = "32G";
      description = ''
        Virtual disk size — a ceiling, not a reservation (the image is
        sparse). Raising it later is easy; lowering it means deleting
        `stateDir/storage` and reinstalling from scratch.
      '';
    };

    cores = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "vCPUs handed to the guest.";
    };

    rdpScale = lib.mkOption {
      type = lib.types.enum [
        100
        140
        180
      ];
      default = 100;
      description = ''
        RemoteApp scaling percentage. FreeRDP only accepts 100, 140 or 180.
        Match it to the output scale the windows land on (niri 1.75 -> 180,
        1.5 -> 140, unscaled -> 100), or text renders tiny.
      '';
    };

    idleTimeout = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = ''
        Minutes with no RemoteApp session open before on-demand mode stops the
        VM. Counted in one-minute checks rather than wall-clock, so a
        suspended laptop doesn't wake up and immediately kill a VM in use.
      '';
    };

    rdpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/drive:home,/home/otis" ];
      description = ''
        Extra flags appended to every FreeRDP invocation.

        The default maps the home directory into the session as a redirected
        drive under "This PC" — a per-session RDP redirection, nothing copied.
        No container-side bind mount alongside it on purpose: one path in is
        enough.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/winapps";
      description = "Holds the VM's virtual disk and the first-boot OEM scripts.";
    };

    apps = lib.mkOption {
      description = ''
        Windows applications to surface as desktop entries. Each id must name
        a directory under `<winapps>/src/apps`, read at build time — a wrong
        id fails the build rather than producing a dead launcher.

        The `-o365` ids target the Office Deployment Tool's install path; the
        unsuffixed (MSI) ids will not resolve here.
      '';
      type = lib.types.listOf lib.types.str;
      default = [
        "word-o365"
        "excel-o365"
        "powerpoint-o365"
        "outlook-o365"
        "onenote-o365"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    # Docker comes from suites.development; asserting (not enabling) it keeps
    # one owner for the daemon and turns dropping that suite into an eval error.
    assertions = [
      {
        assertion = config.services.docker.enable;
        message = "services.winapps needs services.docker (provided by suites.development).";
      }
    ];

    # Read as root: by systemd starting the container, and by ./home.nix's
    # activation script writing winapps.conf.
    sops.secrets.winapps_vm_env = {
      sopsFile = ../../../secrets/winapps.yaml;
      owner = "root";
      mode = "0400";
    };

    virtualisation.oci-containers.backend = "docker";

    virtualisation.oci-containers.containers.windows = {
      image = "dockurr/windows";

      # Not pulled in by multi-user.target — exists only when started.
      autoStart = false;

      environment = {
        VERSION = cfg.version;
        RAM_SIZE = cfg.ram;
        DISK_SIZE = cfg.disk;
        CPU_CORES = toString cfg.cores;
      };

      # USERNAME/PASSWORD via environmentFiles, not `environment` — the
      # latter renders into the unit file in the world-readable Nix store.
      environmentFiles = [ config.sops.secrets.winapps_vm_env.path ];

      volumes = [
        "${cfg.stateDir}/storage:/storage"
        "${cfg.stateDir}/oem:/oem"
      ];

      # Loopback prefixes are load-bearing — without them Docker publishes
      # RDP on every interface.
      ports = [
        "127.0.0.1:8006:8006/tcp"
        "127.0.0.1:3389:3389/tcp"
        "127.0.0.1:3389:3389/udp"
      ];

      extraOptions = [
        "--device=/dev/kvm"
        "--device=/dev/net/tun"
        "--cap-add=NET_ADMIN"
        "--stop-timeout=120" # Windows needs time to shut down cleanly
      ];
    };

    # Longer than the container's own stop-timeout, so systemd doesn't SIGKILL
    # it mid-shutdown and corrupt the guest filesystem.
    systemd.services.docker-windows.serviceConfig.TimeoutStopSec = lib.mkForce 150;

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 root root -"
      # Tighter than its siblings: unattended-install media and data.img
      # carry the account password in plaintext.
      "d ${cfg.stateDir}/storage 0700 root root -"
      "d ${cfg.stateDir}/oem 0755 root root -"
    ];

    # Scoped narrowly so a menu entry can start/stop this one unit without a
    # password prompt — `restart` and every other unit still prompt.
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
