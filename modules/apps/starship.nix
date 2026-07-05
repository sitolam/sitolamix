{ config, lib, ... }:
let
  cfg = config.apps.starship;
in
{
  options.apps.starship.enable = lib.mkEnableOption "starship prompt";

  config = lib.mkIf cfg.enable {
    home.extraOptions.programs.starship = {
      enable = true;
      enableFishIntegration = true;

      # Prompt from github.com/1amSimp1e/dots, recoloured to stylix base16
      # palette names (stylix's starship target sets palette="base16" + defines
      # palettes.base16, and merges with these settings, so colours track the
      # scheme). Converted from the upstream TOML so the Nerd Font glyphs stay
      # byte-exact rather than hand-retyped.
      settings = {
        add_newline = true;
        aws = {
          symbol = "  ";
        };
        c = {
          disabled = true;
        };
        character = {
          error_symbol = "[ ](base08 bold)";
          success_symbol = "[ ](base0D bold)";
        };
        cmake = {
          disabled = true;
        };
        cmd_duration = {
          disabled = false;
          format = "[](fg:base01 bg:none)[$duration]($style)[](fg:base01 bg:base01)[](fg:base0E bg:base01)[󱑂 ](fg:base01 bg:base0E)[](fg:base0E bg:none)";
          min_time = 1;
          style = "fg:base05 bg:base01 bold";
        };
        conda = {
          symbol = " ";
        };
        dart = {
          symbol = " ";
        };
        directory = {
          format = "[](fg:base01 bg:none)[$path]($style)[█](fg:base01 bg:base01)[](fg:base0D bg:base01)[ ](fg:base01 bg:base0D)[](fg:base0D bg:none)";
          read_only = " ";
          style = "fg:base05 bg:base01 bold";
          truncate_to_repo = false;
          truncation_length = 3;
        };
        docker_context = {
          detect_files = [
            "docker-compose.yml"
            "docker-compose.yaml"
            "Dockerfile"
          ];
          detect_folders = [ ];
          disabled = false;
          format = "via [$symbol$context]($style) ";
          only_with_files = true;
          style = "blue bold";
          symbol = " ";
        };
        elixir = {
          symbol = " ";
        };
        elm = {
          symbol = " ";
        };
        fill = {
          style = "bold green";
          symbol = " ";
        };
        format = "$hostname$directory$localip$shlvl$singularity$kubernetes$vcsh$hg_branch$docker_context$package$custom$sudo$fill$git_branch$git_status$git_commit$cmd_duration$jobs$battery$time$status$os$container$shell$line_break$character";
        git_branch = {
          format = "[](fg:base01 bg:none)[$branch]($style)[](fg:base01 bg:base01)[](fg:base0B bg:base01)[](fg:base01 bg:base0B)[](fg:base0B bg:none) ";
          style = "fg:base05 bg:base01";
          symbol = " ";
        };
        git_commit = {
          format = "[\\($hash\\)]($style) [\\($tag\\)]($style)";
          style = "green";
        };
        git_state = {
          am = "AM";
          am_or_rebase = "AM/REBASE";
          bisect = "BISECTING";
          cherry_pick = "CHERRY-PICKING";
          format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
          merge = "MERGING";
          rebase = "REBASING";
          revert = "REVERTING";
          style = "yellow";
        };
        git_status = {
          ahead = "⇡\${count}";
          behind = "⇣\${count}";
          conflicted = "=";
          deleted = " \${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          format = "[](fg:base01 bg:none)[$all_status$ahead_behind]($style)[](fg:base01 bg:base01)[](fg:base0D bg:base01)[ ](fg:base01 bg:base0D)[](fg:base0D bg:none) ";
          modified = "!\${count}";
          renamed = "»\${count}";
          staged = "+\${count}";
          stashed = "";
          style = "fg:base05 bg:base01";
          untracked = "?\${count}";
          up_to_date = " 󰄸 ";
        };
        golang = {
          disabled = true;
          symbol = " ";
        };
        haskell = {
          disabled = true;
          symbol = "λ ";
        };
        hg_branch = {
          symbol = " ";
        };
        hostname = {
          disabled = false;
          format = "[](fg:base01 bg:none)[█](fg:base05 bg:base01)[$ssh_symbol$hostname](bold bg:base05)[](fg:base05 bg:none) ";
          ssh_only = true;
        };
        java = {
          disabled = true;
          symbol = " ";
        };
        julia = {
          symbol = " ";
        };
        line_break = {
          disabled = false;
        };
        lua = {
          disabled = true;
        };
        memory_usage = {
          symbol = " ";
        };
        nim = {
          symbol = " ";
        };
        nix_shell = {
          symbol = " ";
        };
        nodejs = {
          detect_files = [
            "package.json"
            ".node-version"
          ];
          detect_folders = [
            "node_modules"
          ];
          disabled = true;
          format = "via [ Node.js $version](bold green) ";
        };
        package = {
          disabled = true;
          symbol = " ";
        };
        perl = {
          disabled = true;
          symbol = " ";
        };
        php = {
          symbol = " ";
        };
        python = {
          detect_extensions = [
            "py"
          ];
          disabled = true;
          format = "via [\${symbol}python (\${version} )(\\($virtualenv\\) )]($style)";
          pyenv_prefix = "venv ";
          python_binary = [
            "./venv/bin/python"
            "python"
            "python3"
            "python2"
          ];
          style = "bold yellow";
          symbol = " ";
          version_format = "v\${raw}";
        };
        ruby = {
          disabled = true;
          symbol = " ";
        };
        rust = {
          disabled = true;
          symbol = " ";
        };
        scala = {
          symbol = " ";
        };
        shlvl = {
          symbol = " ";
        };
        swift = {
          symbol = "ﯣ ";
        };
      };
    };
  };
}
