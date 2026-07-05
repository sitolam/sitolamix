{ config, lib, ... }:
let
  cfg = config.hardware.nvidia;
in
{
  options.hardware.nvidia.enable = lib.mkEnableOption "NVIDIA GPU drivers and Wayland env";

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      powerManagement.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    environment.variables = {
      CUDA_CACHE_PATH = "$XDG_CACHE_HOME/nv";
      NIXOS_OZONE_WL = "1";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      __GL_VRR_ALLOWED = "0";
    };

    environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";
  };
}
