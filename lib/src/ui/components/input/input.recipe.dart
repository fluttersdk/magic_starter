import 'package:magic/magic.dart';

/// The state axis key for the input recipe.
const String kInputStateAxis = 'state';

/// Visual state variants for [MSInput].
///
/// - [normal] — Default resting state.
/// - [error] — Validation-failed state; applies destructive border color.
enum InputState {
  /// Default resting state.
  normal,

  /// Validation-failed: applies destructive border and ring.
  error,
}

/// The input [WindRecipe] (const — no theme override hook needed).
///
/// Semantic tokens drive background and border so a `DESIGN.md` override
/// re-skins all inputs without touching this file. Width-agnostic: full-width
/// is the dedicated [MSInput.fullWidth] prop (a `SizedBox` wrapper), not a
/// baked-in `w-full` token, so the default renders at content width.
const WindRecipe inputRecipe = WindRecipe(
  base: 'rounded-lg border text-fg text-sm '
      'focus:outline-none focus:ring-2 '
      'disabled:opacity-50 disabled:cursor-not-allowed',
  variants: {
    kInputStateAxis: {
      'normal': 'bg-surface-container-high border-color-border '
          'focus:border-color-border focus:ring-bg-primary',
      'error': 'bg-surface-container-high border-bg-destructive '
          'focus:ring-bg-destructive',
    },
  },
  defaultVariants: {
    kInputStateAxis: 'normal',
  },
);
