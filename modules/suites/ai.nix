{ config, lib, ... }:
let
  cfg = config.suites.ai;
in
{
  options.suites.ai.enable = lib.mkEnableOption "local AI apps (LM Studio, ccl)";

  config = lib.mkIf cfg.enable {
    # ccl launches Claude Code against a model LM Studio is serving; it is useless
    # without LM Studio, so it ships with this suite rather than with development.
    apps.ccl.enable = true;

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
