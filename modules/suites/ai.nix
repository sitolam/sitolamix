{ config, lib, ... }:
let
  cfg = config.suites.ai;
in
{
  options.suites.ai.enable = lib.mkEnableOption "AI apps (LM Studio, ccl, Claude Desktop)";

  config = lib.mkIf cfg.enable {
    # ccl launches Claude Code against a model LM Studio is serving; it is useless
    # without LM Studio, so it ships with this suite rather than with development.
    apps.ccl.enable = true;

    # GUI for the same Claude Code engine as the `claude` CLI (plus Chat/Cowork).
    apps.claude-desktop.enable = true;

    home.extraOptions =
      { pkgs, ... }:
      {
        # LM Studio — GUI to browse, download and run local GGUF models. Ships
        # its own llama.cpp + Vulkan/CUDA runtimes, so no ollama/server module
        # is needed. This box's 8 GB RTX 2060 SUPER wants small quantised
        # models (7B-class Q4, or a fitting MoE) with GPU-offload dialed in.
        home.packages = [ pkgs.lmstudio ];
      };
  };
}
