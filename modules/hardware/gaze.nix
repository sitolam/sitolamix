# Windows Hello-style face authentication (GunduLabs/gaze), replacing howdy.
#
# SECURITY: unlike howdy, gaze does run a liveness/anti-spoofing pass — a local
# MiniFASNet-V2 presentation-attack model on the detected face crop ([liveness]
# in its config, on by default). That raises the bar over howdy's bare 2D
# compare, but it is still one camera, not Hello's structured-light depth
# sensor. It is wired here as a *convenience*:
#
#   - the PAM rule is "sufficient" (upstream's default): a face match unlocks,
#     a miss falls through to the normal password prompt.
#   - scoped to the PAM services named in `pamServices`, not all of them —
#     gaze's own default list (sudo + polkit-1) is replaced, not extended, so
#     nothing reaches sshd.
#
# Want face-as-second-factor instead? There is no `control` knob here; set
# `security.pam.services.<svc>.gaze.control = "required"` from the host.
#
# Why gaze and not howdy: `simultaneousServices` below. howdy sits in the
# sequential PAM auth stack ahead of pam_unix, so the password prompt cannot
# even appear until its scan returns — its timeout had to be cut to 1s to make
# that bearable. gaze ships pam_gaze_grosshack.so, which runs the scan and the
# password prompt at the same time, the way DMS already races fingerprint
# against password (Modules/Lock/Pam.qml).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.hardware.gaze;

  packages = inputs.gaze.packages.${pkgs.stdenv.hostPlatform.system};

  # Both stock packages build with default Cargo features, which is CPU-only:
  # `execution_provider = "openvino"` needs the daemon's `openvino` feature,
  # and `device = "gpu"`/`"npu"` needs gaze-core's `openvino-config`, which
  # every crate that reads or writes the [inference] table has to carry too —
  # otherwise the CLI and the GUI only know `device = "cpu"` and reject or
  # silently rewrite what this module put in config.toml.
  #
  # Everything else — src, cargoLock, the ORT_STRATEGY=system env that links
  # nixpkgs' onnxruntime instead of letting ort download one, the GStreamer
  # wrappers — is upstream's, so only the build flags are overridden; the
  # buildPhase below is a verbatim copy of packaging/nix/gaze.nix's with the
  # feature flags added. Drop all of this if upstream ever exposes the feature
  # as a package argument.
  withOpenvino =
    package: overrides: if !cfg.openvino.enable then package else package.overrideAttrs overrides;

  gazePackage = withOpenvino packages.gaze {
    buildPhase = ''
      runHook preBuild
      cargo build --release --offline -p gaze --features openvino
      cargo build --release --offline -p gaze-cli -p pam-gaze -p pam-gaze-grosshack \
        --features gaze-cli/openvino
      runHook postBuild
    '';
  };

  guiPackage = withOpenvino packages.gaze-gui (old: {
    cargoBuildFlags = old.cargoBuildFlags ++ [
      "--features"
      "gaze-gui/openvino"
    ];
  });
in
{
  imports = [ inputs.gaze.nixosModules.default ];

  options.hardware.gaze = {
    enable = lib.mkEnableOption "gaze face authentication (see the security note in this file)";

    irDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/v4l/by-path/pci-0000:00:14.0-usb-0:3:1.2-video-index0";
      description = ''
        The *IR* camera node — not the colour one. `/dev/videoN` numbering is
        not stable across boots; prefer a `/dev/v4l/by-path/...` symlink once
        you know which device it is. Find it on the machine with:

        ```sh
        v4l2-ctl --list-devices
        v4l2-ctl -d /dev/videoN --list-formats-ext   # the IR one is GREY-only
        gaze doctor                                  # what gaze itself sees
        ```

        Left null, gaze authenticates off the colour camera alone
        (`cameras.rgb = "primary"`, resolved through PipeWire at runtime).
      '';
    };

    irEmitter.enable = lib.mkEnableOption ''
      driving the camera's IR LED during authentication. Needed only for
      cameras whose emitter does not light up on its own — the IR frames come
      back black otherwise. Requires `irDevice`
    '';

    pamServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "login"
        "greetd"
        "sudo"
        "polkit-1"
      ];
      description = ''
        PAM services that get face authentication. Replaces gaze's own default
        of sudo + polkit-1.

        `login` is what the DMS lock screen authenticates against — DMS mirrors
        it into a user-local `dankshell` service at first lock (`dms auth
        resolve-lock`, Modules/Lock/Pam.qml) rather than shipping a PAM file of
        its own — `greetd` is the dms-greeter login screen.
      '';
    };

    simultaneousServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "login"
        "greetd"
      ];
      description = ''
        Which of `pamServices` use pam_gaze_grosshack.so, which runs the face
        scan concurrently with the password prompt, instead of the sequential
        pam_gaze.so. Only worth it where a human is already staring at a
        password field — the lock screen and the greeter. sudo and polkit are
        left sequential: upstream's default, and the scan there is short
        enough that racing it buys nothing.

        Entries not in `pamServices` are ignored.
      '';
    };

    openvino.enable =
      lib.mkEnableOption ''
        the OpenVINO execution provider, so inference runs on the iGPU or the
        NPU instead of the CPU. Builds gaze with its `openvino` Cargo feature.
        Implied by any `device` other than "cpu"
      ''
      // {
        default = cfg.device != "cpu";
        defaultText = lib.literalExpression ''config.hardware.gaze.device != "cpu"'';
      };

    device = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "gpu"
        "npu"
      ];
      default = "cpu";
      description = ''
        Which OpenVINO device runs the detection and recognition models.

        "npu" needs an Intel NPU exposed at /dev/accel/accel0
        (`hardware.cpu.intel.npu.enable`, which ships intel-npu-driver and
        level-zero). Nothing else has to be built specially: nixpkgs'
        onnxruntime already carries libonnxruntime_providers_openvino.so, and
        nixpkgs' openvino already carries libopenvino_intel_npu_plugin.so.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.gaze = {
      enable = true;
      package = gazePackage;
      # The GTK4 settings/enrollment UI. It writes through the daemon into
      # /etc/gaze/config.toml, which is why mutableConfig stays at its default
      # of true — the file is seeded from `settings` once, then left editable.
      # Consequence: changing `settings` here does *not* rewrite an existing
      # /etc/gaze/config.toml. Edit it in the GUI, or delete it and rebuild.
      gui = {
        enable = true;
        package = guiPackage;
      };
      # Ours is `pamServices`; leaving this at its default would additionally
      # turn gaze on for sudo and polkit-1 behind the list's back.
      pam.defaultServices = [ ];

      settings = {
        inference = {
          execution_provider = if cfg.openvino.enable then "openvino" else "cpu";
          inherit (cfg) device;
        };

        cameras = lib.mkIf (cfg.irDevice != null) {
          ir = cfg.irDevice;
          emitter_enabled = cfg.irEmitter.enable;
        };
      };
    };

    security.pam.services = lib.genAttrs cfg.pamServices (name: {
      gaze = {
        enable = true;
        simultaneous = lib.elem name cfg.simultaneousServices;
      };
    });

    # v4l-utils: `v4l2-ctl --list-devices`, to find the IR node in the first
    # place. gaze itself is installed by its own module.
    environment.systemPackages = [ pkgs.v4l-utils ];
  };
}
