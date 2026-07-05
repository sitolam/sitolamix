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

      # Colours come from stylix's starship target, which sets `palette = "base16"`
      # and defines `palettes.base16` (base00..base0F + semantic names like
      # red/green/blue/yellow). We only reference those names here, so the prompt
      # follows the active stylix scheme instead of hardcoded hex.
      settings = {
        add_newline = true;

        # (the upstream config used TOML `\`-continuations, which collapse to a
        # single logical line; the visible line break comes from $line_break.)
        format = "$hostname$directory$localip$shlvl$singularity$kubernetes$vcsh$hg_branch$docker_context$package$custom$sudo$fill$git_branch$git_status$git_commit$cmd_duration$jobs$battery$time$status$os$container$shell$line_break$character";

        hostname = {
          ssh_only = true;
          format = "[](fg:base01 bg:none)[█](fg:base05 bg:base01)[$ssh_symbol$hostname](bold bg:base05)[](fg:base05 bg:none) ";
          disabled = false;
        };

        directory = {
          format = "[](fg:base01 bg:none)[$path]($style)[█](fg:base01 bg:base01)[](fg:base0D bg:base01)[ ](fg:base01 bg:base0D)[](fg:base0D bg:none)";
          style = "fg:base05 bg:base01 bold";
          truncation_length = 3;
          truncate_to_repo = false;
          read_only = " ";
        };

        character = {
          success_symbol = "[ ](base0D bold)";
          error_symbol = "[ ](base08 bold)";
        };

        line_break.disabled = false;

        fill = {
          symbol = " ";
          style = "bold green";
        };

        cmd_duration = {
          min_time = 1;
          format = "[](fg:base01 bg:none)[$duration]($style)[](fg:base01 bg:base01)[](fg:base0E bg:base01)[󱑂 ](fg:base01 bg:base0E)[](fg:base0E bg:none)";
          disabled = false;
          style = "fg:base05 bg:base01 bold";
        };

        git_branch = {
          format = "[](fg:base01 bg:none)[$branch]($style)[](fg:base01 bg:base01)[](fg:base0B bg:base01)[](fg:base01 bg:base0B)[](fg:base0B bg:none) ";
          style = "fg:base05 bg:base01";
          symbol = " ";
        };

        git_status = {
          format = "[](fg:base01 bg:none)[$all_status$ahead_behind]($style)[](fg:base01 bg:base01)[](fg:base0D bg:base01)[ ](fg:base01 bg:base0D)[](fg:base0D bg:none) ";
          style = "fg:base05 bg:base01";
          conflicted = "=";
          ahead = "⇡\${count}";
          behind = "⇣\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          up_to_date = " 󰄸 ";
          untracked = "?\${count}";
          stashed = "";
          modified = "!\${count}";
          staged = "+\${count}";
          renamed = "»\${count}";
          deleted = " \${count}";
        };

        git_commit = {
          format = "[\\($hash\\)]($style) [\\($tag\\)]($style)";
          style = "green";
        };

        git_state = {
          rebase = "REBASING";
          merge = "MERGING";
          revert = "REVERTING";
          cherry_pick = "CHERRY-PICKING";
          bisect = "BISECTING";
          am = "AM";
          am_or_rebase = "AM/REBASE";
          style = "yellow";
          format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
        };

        # ── symbols ──
        aws.symbol = "  ";
        conda.symbol = " ";
        dart.symbol = " ";
        docker_context = {
          symbol = " ";
          format = "via [$symbol$context]($style) ";
          style = "blue bold";
          only_with_files = true;
          detect_files = [
            "docker-compose.yml"
            "docker-compose.yaml"
            "Dockerfile"
          ];
          detect_folders = [ ];
          disabled = false;
        };
        elixir.symbol = " ";
        elm.symbol = " ";
        hg_branch.symbol = " ";
        julia.symbol = " ";
        memory_usage.symbol = " ";
        nim.symbol = " ";
        nix_shell.symbol = " ";
        php.symbol = " ";
        scala.symbol = " ";
        shlvl.symbol = " ";
        swift.symbol = "ﯣ ";

        nodejs = {
          format = "via [ Node.js $version](bold green) ";
          detect_files = [
            "package.json"
            ".node-version"
          ];
          detect_folders = [ "node_modules" ];
          disabled = true;
        };

        python = {
          symbol = " ";
          format = "via [\${symbol}python (\${version} )(\\($virtualenv\\) )]($style)";
          style = "bold yellow";
          pyenv_prefix = "venv ";
          python_binary = [
            "./venv/bin/python"
            "python"
            "python3"
            "python2"
          ];
          detect_extensions = [ "py" ];
          version_format = "v\${raw}";
          disabled = true;
        };

        # ── languages disabled (symbol kept where the upstream set one) ──
        haskell = {
          symbol = "λ ";
          disabled = true;
        };
        java = {
          symbol = " ";
          disabled = true;
        };
        perl = {
          symbol = " ";
          disabled = true;
        };
        package = {
          symbol = " ";
          disabled = true;
        };
        ruby = {
          symbol = " ";
          disabled = true;
        };
        rust = {
          symbol = " ";
          disabled = true;
        };
        golang = {
          symbol = " ";
          disabled = true;
        };
        c.disabled = true;
        cmake.disabled = true;
        lua.disabled = true;
      };
    };
  };
}
