# Windows Hello-style face authentication (GunduLabs/gaze), replacing howdy.
#
# SECURITY: convenience, not a second factor — one camera with liveness
# detection, not Hello's depth sensor. PAM rule is "sufficient": a miss falls
# through to the password prompt. Only `pamServices` get it, replacing gaze's
# own sudo+polkit-1 default. For a second factor, set
# `security.pam.services.<svc>.gaze.control = "required"` from the host.
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

  # Stock packages build CPU-only. openvino/gpu/npu need the `openvino`
  # Cargo feature across every crate touching [inference], or the CLI/GUI
  # reject config.toml. Drop this if upstream exposes it as a package argument.
  withOpenvino =
    package: overrides: if !cfg.openvino.enable then package else package.overrideAttrs overrides;

  gazePackage = withOpenvino packages.gaze {
    buildPhase = ''
      runHook preBuild
      cargo build --release --offline -p gazed --features openvino
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
        VID:PID from `lsusb`): gaze resolves that to the infrared V4L2 node
        itself, surviving `/dev/videoN` renumbering. A bare `/dev/video<n>`
        also works; a `/dev/v4l/by-path/...` symlink does not.

        Find it with `lsusb`, `v4l2-ctl --list-devices`, or `gaze doctor`.
        Left null, gaze authenticates off the colour camera alone.
      '';
    };

    irEmitter.enable = lib.mkEnableOption ''
      driving the camera's IR LED during authentication. Needed only when the
      emitter doesn't light up on its own, leaving IR frames black. Requires `irDevice`
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
        PAM services that get face authentication, replacing gaze's own
        default of sudo + polkit-1. `login` is what the DMS lock screen
        authenticates against; `greetd` is the dms-greeter login screen.
      '';
    };

    simultaneousServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "login"
        "greetd"
      ];
      description = ''
        Which of `pamServices` race the scan against the password prompt
        (pam_gaze_grosshack.so) instead of scanning sequentially — worth it
        only where a human is already staring at a password field. Entries
        not in `pamServices` are ignored.
      '';
    };

    unlockKeyring = lib.mkEnableOption ''
      unlocking the GNOME keyring after a face login at the greeter. gaze
      replays the login password from a TPM-sealed record (enroll it once
      with `gaze keyring`). Root on this machine can recover that password,
      and the greeter's scan becomes sequential instead of simultaneous
    '';

    duress.enable = lib.mkEnableOption ''
      refusing a forced face unlock: hold an eye closed while the camera sees
      you and gaze rejects the match and turns face unlock off for your user
      until a password login or `gaze duress --clear`
    '';

    openvino.enable =
      lib.mkEnableOption ''
        the OpenVINO execution provider, running inference on the iGPU or NPU
        instead of the CPU. Implied by any `device` other than "cpu"
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
        Which OpenVINO device runs detection and recognition. "npu" needs an
        Intel NPU exposed at /dev/accel/accel0 (`hardware.cpu.intel.npu.enable`).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.device != "npu" || config.hardware.cpu.intel.npu.enable;
        message = ''
          hardware.gaze.device = "npu" needs hardware.cpu.intel.npu.enable —
          without it OpenVINO enumerates no NPU and gaze silently runs every
          model on the CPU instead.
        '';
      }
    ];

    services.gaze = {
      enable = true;
      package = gazePackage;
      # Upstream's mutableConfig = true seeds config.toml once, then ignores
      # later `settings` changes. false makes it a read-only symlink instead
      # (the GUI's settings page can no longer save; enrollment is unaffected).
      mutableConfig = false;
      gui = {
        enable = true;
        package = guiPackage;
      };
      # Ours is `pamServices`; this default would enable gaze for sudo/polkit behind the list's back.
      pam.defaultServices = [ ];

      settings = {
        # Keyring unlock needs TPM-encrypted templates and liveness.
        storage = lib.mkIf cfg.unlockKeyring {
          encrypt_templates = true;
          unlock_gnome_keyring = true;
        };
        liveness = lib.mkIf cfg.unlockKeyring { enabled = true; };
        duress = lib.mkIf cfg.duress.enable { enabled = true; };

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

    security.pam.services = lib.mkMerge [
      (lib.genAttrs cfg.pamServices (name: {
        gaze = {
          enable = true;
          simultaneous = lib.elem name cfg.simultaneousServices && !(cfg.unlockKeyring && name == "greetd");
        };
      }))

      # Only sequential pam_gaze.so sets PAM_AUTHTOK, and "sufficient" would
      # return before pam_gnome_keyring sees it. So on a face match, skip the
      # password substack and go straight to the keyring (gaze's gdm-face layout).
      (lib.mkIf cfg.unlockKeyring {
        greetd = {
          gaze.control = "[success=1 default=ignore]";
          rules.auth.gnome_keyring_face = {
            control = "optional";
            modulePath = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
            args = [ "use_authtok" ];
            order = config.security.pam.services.greetd.rules.auth.login.order + 10;
          };
        };
      })
    ];

    security.tpm2.enable = lib.mkIf cfg.unlockKeyring true;

    # OpenVINO's NPU/GPU plugin dlopens the Level Zero loader by bare name;
    # without this on gazed's link path, it silently falls back to CPU.
    systemd.services.gazed.environment.LD_LIBRARY_PATH = lib.mkIf cfg.openvino.enable (
      lib.makeLibraryPath [ pkgs.level-zero ] + ":/run/opengl-driver/lib"
    );

    # For `v4l2-ctl --list-devices` when hunting the IR node.
    environment.systemPackages = [ pkgs.v4l-utils ];
  };
}
