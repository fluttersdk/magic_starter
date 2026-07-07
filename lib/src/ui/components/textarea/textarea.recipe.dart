import 'package:magic/magic.dart';

/// The state axis key for the textarea recipe.
const String kTextareaStateAxis = 'state';

/// Visual state variants for [Textarea].
///
/// - [normal] — Default resting state.
/// - [error] — Validation-failed state; applies destructive border color.
enum TextareaState {
  /// Default resting state.
  normal,

  /// Validation-failed: applies destructive border and ring.
  error,
}

/// The textarea [WindRecipe] (const — no theme override hook needed).
///
/// Mirrors [inputRecipe] but does not set `maxLines` (the [Textarea] widget
/// configures multiline on [WInput] separately). Width-agnostic: full-width
/// is the dedicated [Textarea.fullWidth] prop (a `SizedBox` wrapper), not a
/// baked-in `w-full` token, so the default renders at content width.
const WindRecipe textareaRecipe = WindRecipe(
  base: 'rounded-lg border text-fg text-sm resize-none '
      'focus:outline-none focus:ring-2 '
      'disabled:opacity-50 disabled:cursor-not-allowed',
  variants: {
    kTextareaStateAxis: {
      'normal': 'bg-surface-container-high border-color-border '
          'focus:border-color-border focus:ring-bg-primary',
      'error': 'bg-surface-container-high border-bg-destructive '
          'focus:ring-bg-destructive',
    },
  },
  defaultVariants: {
    kTextareaStateAxis: 'normal',
  },
);
