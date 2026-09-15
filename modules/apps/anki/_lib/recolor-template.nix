# ReColor's dark-mode colours as a matugen template: a flat JSON object of
# key -> hex. ./default.nix's recolorApply merges it into the dark slot of
# ReColor's meta.json. Structural keys map to Material 3 roles; keys whose
# meaning is a hue (flags, card states) map to dank16, the harmonised ANSI
# palette DMS derives from the same scheme.
{ lib, keys }:
let
  c = role: "{{colors.${role}.default.hex}}";
  d = n: "{{dank16.color${toString n}.default.hex}}";

  map' = {
    ACCENT_CARD = c "secondary";
    ACCENT_DANGER = c "error";
    ACCENT_NOTE = d 2;
    BORDER = c "outline_variant";
    BORDER_FOCUS = c "primary";
    BORDER_STRONG = c "outline";
    BORDER_SUBTLE = c "surface_container_high";
    BUTTON_BG = c "surface_container_high";
    BUTTON_DISABLED = c "surface_container_high";
    BUTTON_HOVER = c "surface_container_highest";
    BUTTON_HOVER_BORDER = c "outline";
    BUTTON_PRIMARY_BG = c "primary_container";
    BUTTON_PRIMARY_DISABLED = c "surface_container_highest";
    BUTTON_PRIMARY_GRADIENT_END = c "primary_container";
    BUTTON_PRIMARY_GRADIENT_START = c "primary";
    CANVAS = c "surface";
    CANVAS_CODE = c "surface_container_low";
    CANVAS_ELEVATED = c "surface_container_low";
    CANVAS_GLASS = "{{colors.surface_container_low.default.hex_stripped}}66";
    CANVAS_INSET = c "surface_container_lowest";
    CANVAS_OVERLAY = c "surface_container_low";
    FG = c "on_surface";
    FG_DISABLED = c "outline";
    FG_FAINT = c "outline";
    FG_LINK = c "primary";
    FG_SUBTLE = c "on_surface_variant";
    FLAG_1 = d 1;
    FLAG_2 = d 9;
    FLAG_3 = d 2;
    FLAG_4 = d 4;
    FLAG_5 = d 5;
    FLAG_6 = d 6;
    FLAG_7 = d 13;
    HIGHLIGHT_BG = c "secondary_container";
    HIGHLIGHT_FG = c "on_secondary_container";
    SCROLLBAR_BG = c "surface";
    SCROLLBAR_BG_ACTIVE = c "surface_container_high";
    SCROLLBAR_BG_HOVER = c "surface";
    SELECTED_BG = c "secondary_container";
    SELECTED_FG = c "on_secondary_container";
    SHADOW = c "shadow";
    SHADOW_FOCUS = c "primary";
    SHADOW_INSET = c "surface_container_lowest";
    SHADOW_SUBTLE = c "surface_container_low";
    STATE_BURIED = c "outline";
    STATE_LEARN = d 1;
    STATE_MARKED = d 3;
    STATE_NEW = d 4;
    STATE_REVIEW = d 2;
    STATE_SUSPENDED = c "on_surface_variant";
  };

  # Fail at eval time if ReColor's schema gains or loses a key, rather than
  # silently leaving a slot on its light value.
  missing = lib.subtractLists (lib.attrNames map') keys;
  extra = lib.subtractLists keys (lib.attrNames map');
in
assert lib.assertMsg (missing == [ ]) "anki recolor template: no token for ${toString missing}";
assert lib.assertMsg (extra == [ ]) "anki recolor template: unknown ReColor keys ${toString extra}";
builtins.toJSON map'
