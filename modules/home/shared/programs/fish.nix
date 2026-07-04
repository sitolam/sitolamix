_:
{
  flake.modules.homeManager.shared = {
    programs.fish = {
      enable = true;

      interactiveShellInit = ''
        if command -q mise
          mise activate fish | source
        end

        if command -q zoxide
          zoxide init fish | source
        end

        if command -q atuin
          atuin init fish | source
        end
      '';

      shellInit = ''
        fish_add_path -g $HOME/.local/bin
      '';

      shellAliases = {
        rebuild = "nh os switch path:$HOME/sitolamix";
        update = "nix flake update --flake path:$HOME/sitolamix && nh os switch path:$HOME/sitolamix";
        check = "nix flake check --no-build path:$HOME/sitolamix";
        drybuild = "nix build path:$HOME/sitolamix#nixosConfigurations.gamingpc.config.system.build.toplevel --dry-run";
        diff = "nix build path:$HOME/sitolamix#nixosConfigurations.gamingpc.config.system.build.toplevel && nvd diff /run/current-system result";
        doctor = "check && drybuild";
        ports = "lsof -Pan -iTCP -sTCP:LISTEN";
        sm = "cd $HOME/sitolamix";
        c = "clear";
        cat = "bat";
        du = "dust";
        ll = "eza -la --icons=auto --group-directories-first";
        ls = "eza --icons=auto --group-directories-first";
        la = "eza -la --icons=auto --group-directories-first";
        lt = "eza --tree --icons=auto --group-directories-first";
        grep = "rg";
        find = "fd";
        top = "btop";
        g = "git";
        gs = "git status --short --branch";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gl = "git lg";
        lg = "lazygit";
        ld = "lazydocker";
        k = "kubectl";
        tf = "tofu";
        dcu = "docker compose up -d";
        dcd = "docker compose down";
        dcl = "docker compose logs -f";
        dcp = "docker compose ps";
        ndev = "nix develop";
        nrun = "nix run";
        nshell = "nix shell";
        nsearch = "nix search nixpkgs";
        nixgc = "nix store gc";
        ghpr = "gh pr create";
        ghco = "gh pr checkout";
        ghpv = "gh pr view --web";
      };

      functions = {
        just = ''
          if test -e ./Justfile
            command just $argv
          else
            command just --justfile /home/otis/sitolamix/Justfile --working-directory /home/otis/sitolamix $argv
          end
        '';

        mkcd = ''
          mkdir -p -- $argv[1]
          and cd -- $argv[1]
        '';

        extract = ''
          if test (count $argv) -ne 1
            echo "usage: extract <archive>"
            return 1
          end

          switch $argv[1]
            case "*.tar.bz2" "*.tbz2"
              tar xjf $argv[1]
            case "*.tar.gz" "*.tgz"
              tar xzf $argv[1]
            case "*.tar.xz" "*.txz"
              tar xJf $argv[1]
            case "*.tar.zst" "*.tzst"
              tar --zstd -xf $argv[1]
            case "*.tar"
              tar xf $argv[1]
            case "*.zip"
              unzip $argv[1]
            case "*.gz"
              gunzip $argv[1]
            case "*.bz2"
              bunzip2 $argv[1]
            case "*.xz"
              unxz $argv[1]
            case "*"
              echo "extract: unsupported archive: $argv[1]"
              return 1
          end
        '';

        serve = ''
          set port 8000
          if test (count $argv) -ge 1
            set port $argv[1]
          end
          python3 -m http.server $port
        '';
      };
    };
  };
}
