{ config, lib, ... }:
let
  cfg = config.suites.ai;
in
{
  options.suites.ai.enable = lib.mkEnableOption "AI apps (LM Studio, ccl, cco/OmniRoute, Claude Desktop)";

  config = lib.mkIf cfg.enable {
    # ccl launches Claude Code against a model LM Studio is serving; it is useless
    # without LM Studio, so it ships with this suite rather than with development.
    apps.ccl.enable = true;

    # cco is the same idea against OmniRoute instead of LM Studio: a gateway in
    # front of ~350 providers rather than one local model. It pulls in
    # services.omniroute itself, which is the container the gateway runs in.
    apps.cco.enable = true;

    # GUI for the same Claude Code engine as the `claude` CLI (plus Chat/Cowork).
    apps.claude-desktop.enable = true;

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
