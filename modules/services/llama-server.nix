{
  config,
  lib,
  ...
}:
let
  cfg = config.services.llama-server;
in
{
  # Not `services.llama-cpp` — that name is taken by the nixpkgs module, which
  # runs llama-server as a system service under a DynamicUser that cannot read a
  # GGUF out of $HOME. This one is a home-manager user service for exactly that
  # reason, and pairs it with the GPU watchdog fix below, which nixpkgs has no
  # notion of.
  options.services.llama-server = {
    enable = lib.mkEnableOption "llama.cpp server (Vulkan) for local models";

    modelPath = lib.mkOption {
      type = lib.types.str;
      description = ''
        Absolute path to the GGUF to serve. Not a Nix path: these files are tens
        of gigabytes and are fetched by hand, so copying one into the store would
        double the disk cost and rebuild the closure on every model swap.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 18080;
      description = "Port llama-server listens on (127.0.0.1 only).";
    };

    contextSize = lib.mkOption {
      type = lib.types.int;
      default = 131072;
      description = ''
        Context window in tokens. 131072 is what fits alongside a running desktop
        on this box; see the memory arithmetic in the ubatch comment below.
      '';
    };

    ubatch = lib.mkOption {
      type = lib.types.int;
      default = 1024;
      description = ''
        Physical batch size. This is the GPU-watchdog knob, not just a speed knob
        — see the job_timeout_ms comment in the config below.
      '';
    };

    idleSeconds = lib.mkOption {
      type = lib.types.int;
      default = 900;
      description = ''
        Seconds of inactivity after which the server releases the model and
        sleeps. Measured on this box: sleeping hands back the GPU heap (15.2 GiB
        of 23.07 free again, against 16.75 GiB with nothing loaded at all), and
        the next request wakes it in ~35 s. That is what makes it reasonable to
        leave the unit running all session — idle costs a port and a process,
        not 16 GiB.
      '';
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra flags appended to the llama-server command line.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Panther Lake's `xe` driver kills any GPU job that runs longer than
    # job_timeout_ms and resets the compute engine; llama.cpp then dies with
    # `vk::DeviceLostError`. Measured on this machine: a 27B model at 64k context
    # with --ubatch 2048 trips it reproducibly, leaving
    #   xe 0000:00:02.0: [drm] Tile0: GT0: Timedout job: ... in llama-bench
    #   xe 0000:00:02.0: [drm] Tile0: GT0: Engine reset: engine_class=ccs
    # in dmesg. The default is 5000 ms and the driver caps the value at
    # job_timeout_max = 10000, so this raises it to that ceiling — there is no
    # `xe` module parameter for it, and the sysfs write does not survive a reboot,
    # hence the service. Keep services.llama-server.ubatch low enough that a single
    # submission still fits inside 10 s; 1024 has margin, 2048 does not at depth.
    #
    # Drop this once the xe scheduler stops timing out long compute submissions,
    # or once it exposes a larger job_timeout_max.
    systemd.services.xe-gpu-job-timeout = {
      description = "Raise Intel xe GPU job timeout for long compute submissions";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Card numbering is not stable across boots, so glob rather than name card0.
        for f in /sys/class/drm/card*/device/tile*/gt*/engines/ccs/job_timeout_ms; do
          [ -w "$f" ] && echo 10000 > "$f"
        done
        exit 0
      '';
    };

    home.extraOptions =
      { pkgs, ... }:
      let
        llama = pkgs.llama-cpp.override { vulkanSupport = true; };
      in
      {
        home.packages = [ llama ];

        systemd.user.services.llama-server = {
          Unit = {
            Description = "llama.cpp server (Vulkan)";
            After = [ "graphical-session.target" ];
          };
          # Started at login rather than on demand by ccl. Pairing autostart with
          # --sleep-idle-seconds gets both halves: ccl always finds a server to
          # talk to, and an unused one is asleep rather than holding the weights.
          Install.WantedBy = [ "default.target" ];
          Service = {
            # Loading 14 GB off disk into the GPU heap takes well over a minute
            # cold, and systemd's default 90 s start timeout would kill it midway.
            TimeoutStartSec = "10min";
            Restart = "on-failure";
            RestartSec = 10;
            ExecStart = lib.escapeShellArgs (
              [
                "${llama}/bin/llama-server"
                "--model"
                cfg.modelPath
                "--host"
                "127.0.0.1"
                "--port"
                (toString cfg.port)
                "--alias"
                "local"
                # Everything on the iGPU. This is a UMA part, so "VRAM" is just
                # system RAM — there is no host/device copy to avoid by holding
                # layers back, and every layer left on the CPU is a straight loss.
                "--n-gpu-layers"
                "99"
                "--flash-attn"
                "on"
                # KV precision. Measured on this model: 16 full-attention layers of
                # 4 KV heads at head_dim 256 cost 64 KiB/token at f16, so a 128k
                # window would be 8 GiB of KV alone and would not fit beside the
                # weights. q8_0 keys + q4_0 values cut that to ~3 GiB, and keys are
                # the half that matters for attention accuracy.
                "--cache-type-k"
                "q8_0"
                "--cache-type-v"
                "q4_0"
                "--ctx-size"
                (toString cfg.contextSize)
                "--batch-size"
                "4096"
                "--ubatch-size"
                (toString cfg.ubatch)
                # The GGUF carries Qwen's MTP (`nextn`) head, so speculative
                # decoding needs no second model. Measured: 5.8 -> 7.0 tok/s, with
                # 73% draft acceptance and a mean accepted run of 3.2 tokens.
                "--spec-type"
                "draft-mtp"
                # Claude Code sends one long conversation, not four; extra slots
                # would divide the context window between them for nothing.
                "--parallel"
                "1"
                # Honour the chat template baked into the GGUF. Without this the
                # Dirk template's terseness and reasoning_effort defaults are
                # ignored and the model reverts to stock behaviour.
                "--jinja"
                # Release the weights when nobody is using them. Without this the
                # server pins its whole context allocation for the entire login
                # session, which on a UMA part is memory taken from the desktop.
                "--sleep-idle-seconds"
                (toString cfg.idleSeconds)
              ]
              ++ cfg.extraFlags
            );
          };
        };
      };
  };
}
