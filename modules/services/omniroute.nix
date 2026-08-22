{
  config,
  lib,
  ...
}:
let
  cfg = config.services.omniroute;
in
{
  # ── Why a container and not a package ─────────────────────────────────────
  # OmniRoute is a Next.js app with a native-module tail (better-sqlite3,
  # wreq-js, tls-client-node, keytar) and its own flake ships only a devShell —
  # no package output to consume. The npm tarball does carry a prebuilt
  # standalone bundle, but its postinstall exists purely to shuffle
  # platform-compiled `.node` binaries into that bundle, which is exactly the
  # kind of step a Nix build has to fight. Upstream publishes a version-tagged
  # image instead, and that image is what their own docs deploy, so it is the
  # supported path rather than a shortcut.
  #
  # The image is pinned by digest, not by tag: `diegosouzapw/omniroute:3.8.49`
  # is mutable at the registry, a digest is not. Bumping = pick the new version,
  # then `skopeo inspect docker://docker.io/diegosouzapw/omniroute:<ver>
  # --format '{{.Digest}}'` and paste both below.
  options.services.omniroute = {
    enable = lib.mkEnableOption "OmniRoute AI gateway (containerised, loopback-only)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "3.8.49";
      description = "Upstream release the pinned digest belongs to. Documentation only — `image` is what is pulled.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "diegosouzapw/omniroute@sha256:92c768c56e2de32c51a0621ef182835018b00b288c9bb235c5c5e4514658c1a1";
      description = "Digest-pinned image reference. Must be kept in step with `version`.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 20128;
      description = ''
        Gateway and dashboard port. `cco` reads this to build ANTHROPIC_BASE_URL,
        so changing it here is enough — nothing else hardcodes 20128.
      '';
    };

    wsPort = lib.mkOption {
      type = lib.types.port;
      default = 20132;
      description = ''
        The dashboard's live-update WebSocket. Served on its own listener rather
        than over the dashboard port, so the browser cannot reach it unless it is
        published too. Nothing in the Claude Code path needs it; it is here so the
        dashboard's live views are not permanently blank.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.docker.enable = true;

    virtualisation.oci-containers = {
      # NixOS defaults this to podman. Docker is already the daemon this machine
      # runs (suites.development), and running both would mean two image stores.
      backend = "docker";

      containers.omniroute = {
        inherit (cfg) image;
        autoStart = true;

        # Loopback only. The gateway holds provider credentials and, with
        # REQUIRE_API_KEY at its default of false, serves /v1/* to anyone who can
        # reach it — which must therefore be nobody but this host.
        ports = [
          "127.0.0.1:${toString cfg.port}:${toString cfg.port}"
          "127.0.0.1:${toString cfg.wsPort}:${toString cfg.wsPort}"
        ];

        # A named docker volume rather than a host bind mount: the container runs
        # as its own uid and this is opaque application state (SQLite, encrypted
        # credentials, the auto-generated JWT secret), not anything to edit by
        # hand. Surviving `docker rm` is the whole point — it is what makes an
        # image bump a restart instead of a re-onboarding.
        volumes = [ "omniroute-data:/app/data" ];

        environment = {
          DATA_DIR = "/app/data";
          PORT = toString cfg.port;
          DASHBOARD_PORT = toString cfg.port;
          LIVE_WS_PORT = toString cfg.wsPort;
          LIVE_WS_HOST = "0.0.0.0";
          LIVE_WS_ALLOWED_ORIGINS = "http://localhost:${toString cfg.port},http://127.0.0.1:${toString cfg.port}";
          # Matches upstream's compose file. The Next.js server will happily grow
          # past a default heap on long streaming sessions.
          NODE_OPTIONS = "--max-old-space-size=2048";
        };

        # No env_file, unlike upstream's compose: every secret it would carry
        # (JWT_SECRET, API_KEY_SECRET, STORAGE_ENCRYPTION_KEY) is auto-generated
        # on first boot and persisted into the data volume, so there is nothing
        # for sops to hold and no first-run editing step.
        #
        # Redis is likewise skipped. It only backs rate limiting and circuit
        # breakers, both of which fall back to process-local state when REDIS_URL
        # is unset — correct for a single-user gateway, and one container instead
        # of two.
        extraOptions = [
          # Upstream's stop_grace_period. The gateway checkpoints SQLite on
          # SIGTERM and docker's default 10s is not always enough.
          "--stop-timeout=40"
        ];
      };
    };
  };
}
