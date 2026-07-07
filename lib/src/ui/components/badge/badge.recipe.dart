import 'package:magic/magic.dart';

/// The tone axis key for the badge recipe (`BadgeTone.<value>.name`).
const String kBadgeToneAxis = 'tone';

/// Builds the badge [WindRecipe] using semantic tokens from [MagicStarterTokens].
///
/// The recipe is a top-level const because the badge has no theme-override hook
/// (no `MagicStarter.useBadgeTheme()`); tones read straight from the semantic
/// alias map.
///
/// Emission order: `base ++ tone-variant`.
///
/// Tone -> semantic token mapping:
/// - neutral: `bg-surface-container-high text-fg`
/// - primary: `bg-primary text-on-primary`
/// - accent:  `bg-accent text-on-primary`
/// - success: `bg-success text-on-destructive` (white on green, same as on-destructive)
/// - warning: `bg-warning text-on-destructive` (white on amber)
/// - destructive: `bg-destructive text-on-destructive`
/// - outline: border only via `border border-color-border text-fg` (no fill)
const WindRecipe badgeRecipe = WindRecipe(
  base: 'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
  variants: {
    kBadgeToneAxis: {
      'neutral': 'bg-surface-container-high text-fg',
      'primary': 'bg-primary text-on-primary',
      'accent': 'bg-accent text-on-primary',
      'success': 'bg-success text-on-destructive',
      'warning': 'bg-warning text-on-destructive',
      'destructive': 'bg-destructive text-on-destructive',
      'outline': 'border border-color-border text-fg',
    },
  },
  defaultVariants: {
    kBadgeToneAxis: 'neutral',
  },
);
