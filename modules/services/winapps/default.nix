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
      `windows` subtree in ../../desktop/dms/plugins.nix for the controls
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
