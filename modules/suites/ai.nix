{ config, lib, ... }:
let
  cfg = config.suites.ai;
in
{
  options.suites.ai.enable = lib.mkEnableOption "local AI apps (LM Studio)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        # LM Studio — GUI to browse, download and run local GGUF models. Ships its
        # own llama.cpp + Vulkan/CUDA runtimes (fetched on first launch), so no
        # ollama/server module is needed alongside it. Models land in ~/.lmstudio.
        #
        # Hardware note: this box has an 8 GB RTX 2060 SUPER — keep to small
        # quantised models (7B-class at Q4, or MoE that fit) and use LM Studio's
        # GPU-offload slider; larger models spill to CPU and crawl.
        home.packages = [ pkgs.lmstudio ];
      };
  };
}
