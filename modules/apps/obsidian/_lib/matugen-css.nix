# The Obsidian CSS snippet as a matugen template. Nix fills in what is
# static (font names, the callout list); matugen fills every colour from the
# wallpaper whenever DMS regenerates its scheme. Imported by ../default.nix;
# lives under _lib so import-tree skips it.
{ lib, fonts }:
let
  c = role: "{{colors.${role}.default.hex}}";
  d = n: "{{dank16.color${toString n}.default.hex}}";
  rgbOf =
    prefix: "{{${prefix}.default.red}}, {{${prefix}.default.green}}, {{${prefix}.default.blue}}";
  role = r: "colors.${r}";
  ansi = n: "dank16.color${toString n}";

  headings = [
    (c "primary")
    (c "secondary")
    (c "tertiary")
    (d 6)
    (d 2)
    (c "on_surface_variant")
  ];

  # Same hue families as the old catppuccin table: statements blue-ish,
  # constructions in the accent, proofs deliberately quiet.
  callouts = {
    theorem = ansi 4;
    lemma = ansi 12;
    proposition = ansi 14;
    corollary = ansi 6;
    claim = ansi 12;
    conjecture = role "tertiary";
    hypothesis = role "tertiary";
    assumption = role "tertiary";
    axiom = ansi 13;
    definition = role "primary";
    proof = role "outline";
    solution = role "outline";
    example = ansi 2;
    exercise = ansi 11;
    remark = role "on_surface_variant";
    note = ansi 4;
    info = ansi 14;
    tip = ansi 6;
    success = ansi 2;
    question = ansi 3;
    warning = ansi 11;
    danger = role "error";
    bug = role "error";
    quote = role "tertiary";
    abstract = ansi 6;
  };

  headingVars = lib.concatStringsSep "\n" (
    lib.imap1 (i: v: "  --h${toString i}-color: ${v};") headings
  );

  # Two selectors per entry: Obsidian's own callouts key off data-callout;
  # math-booster re-renders its environments as .theorem-callout-<env> and
  # drops that attribute. !important because math-booster pins
  # --callout-color from a :has() rule no snippet selector can outrank.
  calloutRules = lib.concatStringsSep "\n" (
    lib.mapAttrsToList
      (name: prefix: ''
        .callout[data-callout="${name}"],
        .theorem-callout.theorem-callout-${name} { --callout-color: ${rgbOf prefix} !important; }'')
      callouts
  );
in
''
  /* Rendered by matugen from modules/apps/obsidian/_lib/matugen-css.nix whenever
     the DMS wallpaper changes. Do not edit: the next wallpaper change
     overwrites it. Add a second snippet next to it for personal tweaks. */
  .theme-dark,
  .theme-light {
    --font-text-theme: ${fonts.serif};
    --font-interface-theme: ${fonts.sansSerif};
    --font-monospace-theme: ${fonts.monospace};

    --accent-h: {{colors.primary.default.hue}};
    --accent-s: {{colors.primary.default.saturation}}%;
    --accent-l: {{colors.primary.default.lightness}}%;

    --background-primary: ${c "surface"};
    --background-primary-alt: ${c "surface_container_low"};
    --background-secondary: ${c "surface_container_low"};
    --background-secondary-alt: ${c "surface_container_lowest"};
    --background-modifier-border: ${c "surface_container_high"};
    --background-modifier-border-hover: ${c "surface_container_highest"};
    --background-modifier-border-focus: ${c "primary"};
    --background-modifier-hover: ${c "surface_container_high"};
    --background-modifier-active-hover: ${c "surface_container_highest"};
    --background-modifier-form-field: ${c "surface_container_low"};
    --background-modifier-error: ${c "error"};
    --background-modifier-success: ${d 2};

    --text-normal: ${c "on_surface"};
    --text-muted: ${c "on_surface_variant"};
    --text-faint: ${c "outline"};
    --text-on-accent: ${c "on_primary"};
    --text-error: ${c "error"};
    --text-success: ${d 2};
    --text-accent: ${c "primary"};
    --text-accent-hover: ${c "tertiary"};
    --text-selection: ${c "surface_container_highest"};
    --text-highlight-bg: ${c "surface_container_highest"};

    --link-color: ${c "secondary"};
    --link-color-hover: ${c "tertiary"};
    --link-unresolved-color: ${c "error"};
    --link-external-color: ${c "secondary"};

    --interactive-normal: ${c "surface_container_low"};
    --interactive-hover: ${c "surface_container_high"};
    --interactive-accent: ${c "primary"};
    --interactive-accent-hover: ${c "tertiary"};

    --divider-color: ${c "surface_container_high"};
    --titlebar-background: ${c "surface_container_low"};
    --titlebar-background-focused: ${c "surface_container_low"};
    --tab-text-color-focused-active: ${c "primary"};

    --code-background: ${c "surface_container_low"};
    --code-normal: ${d 9};
    --code-comment: ${c "outline"};

    --tag-color: ${d 6};
    --tag-background: ${c "surface_container_low"};

    --blockquote-border-color: ${c "primary"};
    --table-header-background: ${c "surface_container_low"};
    --table-row-alt-background: ${c "surface_container_low"};

    --checkbox-color: ${c "primary"};
    --checkbox-color-hover: ${c "tertiary"};
    --checkbox-marker-color: ${c "on_primary"};

    --scrollbar-bg: ${c "surface"};
    --scrollbar-thumb-bg: ${c "surface_container_high"};
    --scrollbar-active-thumb-bg: ${c "surface_container_highest"};

  ${headingVars}
  }

  /* math-booster hard-sets the font to "CMU Serif, Times" from the same
     unbeatable rule. Take it back, so the whole vault stays on one typeface. */
  .theorem-callout {
    font-family: var(--font-text) !important;
    /* Its "Framed" style draws a border with no colour, so every environment
       ends up the same grey. Paint it from the environment's own accent. */
    border-color: rgba(var(--callout-color), 0.5) !important;
  }

  .theorem-callout .theorem-callout-main-title {
    color: rgb(var(--callout-color));
  }

  /* MathJax inherits colour from the text around it, which is what you want
     inside a callout. */
  .math { color: inherit; }

  ${calloutRules}
''
