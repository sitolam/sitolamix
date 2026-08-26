{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.apps.claude-code;

  # ── Why this module exists ────────────────────────────────────────────────
  # Left alone, Claude Code owns its own plugin set: it clones each marketplace
  # into ~/.claude/plugins/marketplaces, copies every installed plugin into
  # ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>, and re-pulls both
  # on startup. None of that is reproducible, and none of it survives a fresh
  # machine without network.
  #
  # Two facts make it possible to take that over wholesale:
  #
  #   1. A marketplace source may be `{"source":"directory","path":...}`, and a
  #      directory marketplace is read *in place* — never cloned, never copied.
  #      A read-only /nix/store path is a perfectly good directory marketplace.
  #   2. installed_plugins.json's `installPath` is likewise taken at face value,
  #      so pointing it into the store skips the cache copy entirely. Claude
  #      only creates ~/.claude/plugins/data/<plugin> for the plugin's own
  #      writable state.
  #
  # So Nix builds one marketplace and writes both manifests, and the plugin
  # trees are just flake inputs. There is no cache to go stale: `nix flake
  # update` moves the store paths, the manifests are regenerated, and Claude
  # reads the new trees on next launch.
  #
  # Consequence to be aware of: `/plugin install`, `/plugin uninstall` and the
  # plugin browser's toggles all write to files this module owns, so they no
  # longer stick. Add and remove plugins in `plugins` below instead.

  # One Nix-built marketplace holds every plugin, rather than one directory
  # marketplace per upstream repo. Upstream names cannot all be reused:
  # `claude-plugins-official` is reserved, and Claude rejects it unless its
  # source is a GitHub repo under the `anthropics` org — a store path is not.
  # Serving everything from one marketplace of our own sidesteps that, and
  # keeps plugins whose upstream marketplace only *points* at another repo
  # (see superpowers/figma below) on the same footing as the rest.
  marketplaceName = "sitolamix";

  # `src` is whichever input the plugin's files come from, `subdir` where in
  # that input the plugin.json sits ("" = the tree root). Both are read off the
  # owning upstream marketplace.json's `source` field for that plugin — the
  # directory names rarely match the plugin names.
  mkPlugin = src: subdir: {
    path = if subdir == "" then "${src}" else "${src}/${subdir}";
    # Cosmetic — what `claude plugin list` prints. Nothing is keyed on it now
    # that installPath is a store path, but a rev beats "unknown".
    version = src.shortRev or src.rev or "nix";
  };

  plugins = {
    # Written here rather than fetched: ./_plugin holds the `/sitolamix` skill,
    # the conventions for editing this repo. Kept in-tree so the skill and the
    # code it describes move in the same commit; `_`-prefixed so import-tree
    # does not try to load it as a NixOS module. Its version is a constant
    # because there is no upstream rev to name — the store path already changes
    # whenever the skill does.
    sitolamix = {
      path = "${./_plugin}";
      version = "in-tree";
    };

    # anthropics/claude-plugins-official
    frontend-design = mkPlugin inputs.claude-marketplace-official "plugins/frontend-design";
    # These two are `{"source":"url"}` rows in that marketplace, i.e. pointers
    # at separate repos, so they are not in its tree and get their own inputs.
    superpowers = mkPlugin inputs.claude-plugin-superpowers "";
    figma = mkPlugin inputs.claude-plugin-figma "";

    # JuliusBrussee/caveman — the whole repo is the plugin.
    caveman = mkPlugin inputs.claude-marketplace-caveman "";

    # alirezarezvani/claude-skills ships ~60 plugins out of one repo; these are
    # the ones we take.
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
  };

  pluginNames = lib.attrNames plugins;

  # The marketplace tree: a manifest plus one symlink per plugin. Symlinks
  # rather than copies so a plugin's files stay in exactly one store path, and
  # so the tree rebuilds in a second when the set changes.
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

  # Both manifests carry timestamps Claude only reads to decide when to
  # refresh. Refreshing is exactly what we are preventing, and a real timestamp
  # would change the store path on every rebuild, so pin them to the epoch.
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

  # ~/.claude/plugins/installed_plugins.json. Each value is a list because one
  # plugin can be installed at several scopes; we only ever use `user`.
  installedPlugins = {
    version = 2;
    plugins = lib.mapAttrs' (n: p: {
      name = "${n}@${marketplaceName}";
      value = [
        {
          scope = "user";
          # Via the marketplace tree rather than p.path directly, so this agrees
          # with what the manifest advertises. It is a symlink to the same path.
          installPath = "${marketplace}/${n}";
          inherit (p) version;
          installedAt = epoch;
          lastUpdated = epoch;
        }
      ];
    }) plugins;
  };

  # /etc/claude-code/managed-settings.json — the policy settings source. Chosen
  # over ~/.claude/settings.json because Claude Code writes that file whenever
  # you change the model, theme, or anything else under /config; making it a
  # read-only store symlink would break all of that. Policy settings are
  # read-only by design, so nothing fights over them, and they win over the
  # user's own settings. Nothing here restricts what may be added by hand —
  # `strictKnownMarketplaces` is deliberately not set.
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
          # Claude Code shells out to node/npx for MCP servers and JS tooling,
          # and the package itself doesn't pull a runtime in.
          pkgs.nodejs
        ];

        # nixpkgs' wrapper disables Claude's self-updater but then sets
        # FORCE_AUTOUPDATE_PLUGINS=1, which re-enables *plugin* auto-update on
        # startup — it would try to git-pull store paths on every launch. The
        # wrapper uses setenv(..., overwrite=0), so a value already in the
        # environment survives, and empty reads as false at the one place Claude
        # tests it.
        sessionVariables.FORCE_AUTOUPDATE_PLUGINS = "";

        # force: both files normally exist as Claude-written state, and without
        # it home-manager stops at "would be clobbered" on the first switch.
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
