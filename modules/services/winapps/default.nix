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
      default = "32G";
      description = ''
        Virtual disk size, and a ceiling rather than a reservation — the image
        is sparse, so it only ever consumes what Windows has actually written.

        32G installs Windows and Office comfortably and will get tight after a
        year of updates. Raising it later is easy (dockur grows the disk on the
        next boot); lowering it is not, and means deleting `stateDir/storage`
        and reinstalling from scratch. omnibook is pinned higher in its host
        file for exactly that reason.
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
        RemoteApp scaling, as a percentage. FreeRDP only accepts 100, 140 or
        180, so this is an enum rather than a free number — WinApps would
        otherwise silently round an arbitrary value to the nearest of the three.

        Match it to the output scale the windows land on, or Windows renders at
        1:1 and the text comes out tiny beside everything else: a niri scale of
        1.75 wants 180, 1.5 wants 140, and an unscaled display wants 100.
      '';
    };

    idleTimeout = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = ''
        Minutes with no RemoteApp session open before on-demand mode stops the
        VM. Counted in consecutive one-minute checks rather than wall-clock, so
        a suspended laptop does not wake up and immediately kill a VM you were
        using.
      '';
    };

    rdpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/drive:home,/home/otis" ];
      description = ''
        Extra flags appended to every FreeRDP invocation.

        The default maps the home directory into the session, so it shows up in
        Windows Explorer under "This PC" as a redirected drive. This is how the
        guest reaches your files: a per-session RDP redirection, nothing copied
        and no share to mount. There is deliberately no container-side bind
        mount alongside it — one path in is enough, and two invited the question
        of which one a given file was supposed to be in.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/winapps";
      description = "Holds the VM's virtual disk and the first-boot OEM scripts.";
    };

    apps = lib.mkOption {
      description = ''
        Windows applications to surface as desktop entries. Each id must name a
        directory under `<winapps>/src/apps`; the entry's name, icon and MIME
        associations are read out of that directory at build time, so a wrong id
        fails the build rather than producing a launcher that does nothing.

        The `-o365` ids target `C:\Program Files\Microsoft Office\root\Office16`,
        which is where the Office Deployment Tool installs. The unsuffixed ids
        target MSI install paths and will not resolve here.
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

    # Account credentials for the guest. Read as root twice over: by systemd
    # when it starts the container (environmentFiles below), and by the system
    # activation script in ./home.nix when it writes winapps.conf — neither of
    # those runs as `otis`, so the secret is owned by root, per the spec.
    sops.secrets.winapps_vm_env = {
      sopsFile = ../../../secrets/winapps.yaml;
      owner = "root";
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
    systemd.services.docker-windows.serviceConfig.TimeoutStopSec = lib.mkForce 150;

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 root root -"
      # 0700, tighter than its siblings: dockurr/windows builds its unattended-
      # install media in here, including an autounattend.xml with the account
      # password in plaintext, plus the guest's data.img (the whole Windows
      # filesystem). Only root — i.e. systemd starting the container — ever
      # needs to open this directory.
      "d ${cfg.stateDir}/storage 0700 root root -"
      "d ${cfg.stateDir}/oem 0755 root root -"
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
