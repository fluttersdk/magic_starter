import 'package:magic/magic.dart';

/// The intent axis key for the button recipe.
const String kButtonIntentAxis = 'intent';

/// The size axis key for the button recipe.
const String kButtonSizeAxis = 'size';

/// Visual intent variants for [MSButton].
///
/// - [primary] — Brand-colored filled button for the main call-to-action.
/// - [secondary] — Neutral surface button for secondary actions.
/// - [ghost] — Transparent button for low-emphasis actions.
/// - [destructive] — Red filled button for dangerous or irreversible actions.
enum ButtonIntent {
  /// Main call-to-action: brand-primary background.
  primary,

  /// Secondary action: neutral surface background.
  secondary,

  /// Low-emphasis action: transparent background.
  ghost,

  /// Dangerous action: destructive red background.
  destructive,
}

/// Size variants for [MSButton].
///
/// - [sm] — Compact button for toolbars and dense layouts.
/// - [md] — Default button size for most contexts.
/// - [lg] — Larger button for prominent hero actions.
enum ButtonSize {
  /// Compact button: smaller padding and text.
  sm,

  /// Default button: standard padding and text.
  md,

  /// Large button: generous padding and larger text.
  lg,
}

/// The button [WindRecipe] (const — no theme override hook needed for this
/// component; styling is token-driven via semantic aliases).
///
/// Emission order: `base ++ intent-classes ++ size-classes ++ compound`.
const WindRecipe buttonRecipe = WindRecipe(
  // No `justify-center`: in Wind that maps to WButton's Container alignment,
  // which forces the button to expand and fill its constraints (full-width).
  // A default Button shrinks to its content (the `inline-flex` intent); the
  // single-child label is centered by the shrink-wrapped padding box. A caller
  // `className` APPENDS after this base (parser last-wins resolves conflicts
  // per family), so it refines the base rather than replacing it; full-width is
  // the dedicated `fullWidth` prop (a SizedBox wrapper), not a className token.
  base:
      'inline-flex items-center font-medium rounded-lg '
      'transition-colors disabled:opacity-50 disabled:cursor-not-allowed '
      'focus:outline-none focus:ring-2 focus:ring-offset-1',
  variants: {
    kButtonIntentAxis: {
      'primary':
          'bg-primary text-on-primary hover:opacity-90 focus:ring-color-border',
      'secondary':
          'bg-surface-container-high text-fg border border-color-border '
          'hover:bg-surface-container-high hover:opacity-80',
      'ghost': 'bg-transparent text-fg hover:bg-surface-container-high',
      'destructive':
          'bg-destructive text-on-destructive hover:opacity-90 '
          'focus:ring-bg-destructive',
    },
    kButtonSizeAxis: {
      'sm': 'px-3 py-1.5 text-sm',
      'md': 'px-4 py-2 text-sm',
      'lg': 'px-5 py-3 text-base',
    },
  },
  defaultVariants: {kButtonIntentAxis: 'primary', kButtonSizeAxis: 'md'},
);
