{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.apps.claude-code;

  # Left alone, Claude Code re-clones marketplaces and re-copies plugins on
  # every startup. A marketplace source can instead be a store directory read
  # in place, with installed_plugins.json's installPath pointed at the same
  # path — so Nix builds one marketplace and owns both manifests.
  # Consequence: `/plugin install`/`uninstall` and the plugin browser's
  # toggles write to files this module owns and won't stick; edit `plugins` below.

  # `claude-plugins-official` is reserved for GitHub repos under `anthropics`,
  # so serve everything from our own marketplace name instead.
  marketplaceName = "sitolamix";

  mkPlugin = src: subdir: {
    path = if subdir == "" then "${src}" else "${src}/${subdir}";
    version = src.shortRev or src.rev or "nix"; # cosmetic only
  };

  # cursor/plugins ships pstack with a Cursor manifest, no .claude-plugin/;
  # skills/ and agents/ are auto-discovered the same way, so symlink the tree
  # and generate a plugin.json.
  mkCursorPlugin =
    name: src: subdir:
    let
      tree = if subdir == "" then "${src}" else "${src}/${subdir}";
      version = src.shortRev or src.rev or "nix";
      manifest = pkgs.writers.writeJSON "plugin.json" {
        inherit name version;
        description = "Cursor plugin ${name}, re-manifested for Claude Code by this flake.";
      };
    in
    {
      inherit version;
      path = pkgs.runCommand "claude-plugin-${name}" { } ''
        mkdir -p "$out/.claude-plugin"
        cp ${manifest} "$out/.claude-plugin/plugin.json"
        for entry in ${tree}/*; do
          ln -s "$entry" "$out/$(basename "$entry")"
        done
      '';
    };

  plugins = {
    # anthropics/claude-plugins-official
    frontend-design = mkPlugin inputs.claude-marketplace-official "plugins/frontend-design";
    # separate repos, own inputs
    superpowers = mkPlugin inputs.claude-plugin-superpowers "";
    figma = mkPlugin inputs.claude-plugin-figma "";

    caveman = mkPlugin inputs.claude-marketplace-caveman ""; # JuliusBrussee/caveman

    # alirezarezvani/claude-skills: ~60 plugins from one repo, these are the ones we take
    engineering-skills = mkPlugin inputs.claude-marketplace-skills "engineering-team";
    engineering-advanced-skills = mkPlugin inputs.claude-marketplace-skills "engineering";
    product-skills = mkPlugin inputs.claude-marketplace-skills "product-team";
    marketing-skills = mkPlugin inputs.claude-marketplace-skills "marketing-skill";
    ra-qm-skills = mkPlugin inputs.claude-marketplace-skills "ra-qm-team";
    pm-skills = mkPlugin inputs.claude-marketplace-skills "project-management";
    business-growth-skills = mkPlugin inputs.claude-marketplace-skills "business-growth";
    finance-skills = mkPlugin inputs.claude-marketplace-skills "finance";

    flutter-all = mkPlugin inputs.claude-marketplace-flutter "flutter-all";
    ui-ux-pro-max = mkPlugin inputs.claude-marketplace-ui-ux "";

    mattpocock-skills = mkPlugin inputs.claude-plugin-mattpocock ""; # mattpocock/skills
    pstack = mkCursorPlugin "pstack" inputs.claude-plugin-pstack "pstack";
  };

  pluginNames = lib.attrNames plugins;

  # symlinks, not copies, so each plugin stays in one store path and the set rebuilds instantly
  marketplaceManifest = pkgs.writers.writeJSON "marketplace.json" {
    name = marketplaceName;
    owner.name = "otis";
    description = "Claude Code plugins pinned by this flake.";
    plugins = map (n: {
      name = n;
      source = "./${n}";
    }) pluginNames;
  };

  marketplace = pkgs.runCommand "claude-marketplace-${marketplaceName}" { } ''
    mkdir -p "$out/.claude-plugin"
    cp ${marketplaceManifest} "$out/.claude-plugin/marketplace.json"
    ${lib.concatMapStringsSep "\n" (
      n: ''ln -s ${lib.escapeShellArg plugins.${n}.path} "$out/${n}"''
    ) pluginNames}
  '';

  # pinned so these fields don't change the store path on every rebuild
  epoch = "1970-01-01T00:00:00.000Z";

  marketplaceSource = {
    source = "directory";
    path = "${marketplace}";
  };

  # ~/.claude/plugins/known_marketplaces.json
  knownMarketplaces.${marketplaceName} = {
    source = marketplaceSource;
    installLocation = "${marketplace}";
    lastUpdated = epoch;
    autoUpdate = false;
  };

  # ~/.claude/plugins/installed_plugins.json. Each value is a list because a
  # plugin can be installed at several scopes; we only ever use `user`.
  installedPlugins = {
    version = 2;
    plugins = lib.mapAttrs' (n: p: {
      name = "${n}@${marketplaceName}";
      value = [
        {
          scope = "user";
          installPath = "${marketplace}/${n}"; # via the marketplace tree, matches what it advertises
          inherit (p) version;
          installedAt = epoch;
          lastUpdated = epoch;
        }
      ];
    }) plugins;
  };

  # /etc/claude-code/managed-settings.json, not ~/.claude/settings.json: Claude
  # writes that file on model/theme/config changes, which a store symlink
  # would break. strictKnownMarketplaces stays unset so hand-added ones still work.
  managedSettings = {
    extraKnownMarketplaces.${marketplaceName} = {
      source = marketplaceSource;
      autoUpdate = false;
    };
    enabledPlugins = lib.listToAttrs (
      map (n: lib.nameValuePair "${n}@${marketplaceName}" true) pluginNames
    );
  };
in
{
  options.apps.claude-code.enable = lib.mkEnableOption "Claude Code CLI with a Nix-pinned plugin set";

  config = lib.mkIf cfg.enable {
    environment.etc."claude-code/managed-settings.json".source =
      pkgs.writers.writeJSON "claude-managed-settings.json" managedSettings;

    home.extraOptions = {
      home = {
        packages = [
          pkgs.claude-code
          pkgs.nodejs # Claude shells out to node/npx for MCP servers; not bundled
        ];

        # nixpkgs' wrapper still sets FORCE_AUTOUPDATE_PLUGINS=1, which would
        # git-pull store paths on every launch; override wins since its
        # setenv uses overwrite=0.
        sessionVariables.FORCE_AUTOUPDATE_PLUGINS = "";

        # force: both files normally exist as Claude-written state
        file.".claude/plugins/known_marketplaces.json" = {
          force = true;
          source = pkgs.writers.writeJSON "claude-known-marketplaces.json" knownMarketplaces;
        };
        file.".claude/plugins/installed_plugins.json" = {
          force = true;
          source = pkgs.writers.writeJSON "claude-installed-plugins.json" installedPlugins;
        };
      };
    };
  };
}
