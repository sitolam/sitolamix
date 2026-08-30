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
      example = "usb:0408:5494";
      description = ''
        The *IR* camera — not the colour one. Prefer `usb:VVVV:PPPP` (hex
        VID:PID, `lsusb`): gaze resolves that to the camera's infrared V4L2
        node itself, lowest-numbered first, so it survives the `/dev/videoN`
        renumbering that happens when another camera is plugged in.

        A bare `/dev/video<number>` also works. A
        `/dev/v4l/by-path/...` symlink does **not**: gaze only special-cases
        literal `/dev/video<number>`, `usb:VVVV:PPPP` and `primary`, and
        passes anything else through to `gst_parse_launch` as a source
        element, which fails with `no source element for URI ...`.

        Find it on the machine with:

        ```sh
        lsusb                                        # VID:PID of the camera
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
    assertions = [
      {
        assertion = cfg.device != "npu" || config.hardware.cpu.intel.npu.enable;
        message = ''
          hardware.gaze.device = "npu" needs hardware.cpu.intel.npu.enable —
          without it there is no ivpu driver, no /dev/accel/accel0 and no
          libze_intel_npu.so, so OpenVINO enumerates no NPU and gaze silently
          runs every model on the CPU instead.
        '';
      }
    ];

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
        # Keyring. gaze can only hand PAM a password on the *fallback* path —
        # pam-gaze-core's stash_password_and_fallback() sets PAM_AUTHTOK from
        # what you typed after the face missed. A face match produces no
        # password at all, so pam_gnome_keyring (auth, inside login's stack,
        # which greetd substacks) has nothing to unlock login.keyring with: the
        # session comes up with the daemon running and the keyring locked, and
        # the first app wanting a secret pops a password dialog.
        #
        # abort_before_first_resume refuses face auth until logind has reported
        # one PrepareForSleep cycle, so the first authentication of every boot
        # falls through to the password — which unlocks the keyring — and every
        # unlock after the first suspend is face again. It is gazed-local state,
        # not persisted: restarting the daemon re-arms the gate, and `gaze auth`
        # or the GUI's test button will fail until the machine has suspended
        # once. That is the whole cost, and it is the only fix that keeps the
        # keyring's own password: the alternative is storing that password
        # somewhere readable (sops secret, or a blank keyring) and unlocking
        # from a session service.
        auth.abort_before_first_resume = true;

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

    # OpenVINO's NPU (and GPU) plugin dlopens the Level Zero loader by bare
    # name — `libze_loader.so.1` is not a DT_NEEDED of
    # libopenvino_intel_npu_plugin.so — and the loader in turn looks for the
    # kernel driver's userspace half, libze_intel_npu.so, which
    # hardware.cpu.intel.npu.enable puts in /run/opengl-driver/lib via
    # hardware.graphics.extraPackages. Neither is on a system daemon's link
    # path, so without this OpenVINO enumerates no NPU at all and every model
    # falls back to the CPU provider with "[OpenVINO] Device NPU is not
    # available" — visible only as "Failed to load shared library" in gazed's
    # log, because ort collapses the provider error.
    systemd.services.gazed.environment.LD_LIBRARY_PATH = lib.mkIf cfg.openvino.enable (
      lib.makeLibraryPath [ pkgs.level-zero ] + ":/run/opengl-driver/lib"
    );

    # v4l-utils: `v4l2-ctl --list-devices`, to find the IR node in the first
    # place. gaze itself is installed by its own module.
    environment.systemPackages = [ pkgs.v4l-utils ];
  };
}
