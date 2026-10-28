import 'package:magic/magic.dart';

import 'toast.dart' show ToastVariant;

/// The variant axis key for the toast recipe (`ToastVariant.<value>.name`).
const String kToastVariantAxis = 'variant';

/// Builds the toast [WindRecipe] using semantic tokens.
///
/// The recipe maps each [ToastVariant] to a bg-* semantic token so the toast
/// tone follows the design-system color ramp without hardcoded hex values.
///
/// Emission order: `base ++ variant ++ caller` — no compound variants.
WindRecipe buildToastRecipe() {
  return const WindRecipe(
    base: 'flex flex-row items-center gap-3 px-4 py-3 rounded-lg shadow-md',
    variants: {
      kToastVariantAxis: {
        'info': 'bg-surface border border-color-border text-fg',
        'success': 'bg-success text-white',
        'warning': 'bg-warning text-white',
        'error': 'bg-destructive text-white',
      },
    },
    defaultVariants: {kToastVariantAxis: 'info'},
  );
}

/// Classes the toast box takes on when it carries an action, appended after the
/// recipe and before the caller's className.
///
/// The action is a 44 px cell, so it cannot sit inside the box's `py-3` without
/// making the toast 24 px taller than one without an action. The vertical
/// padding moves to the message (see [toastActionRecipe]) and the box gives the
/// cell the room it needs on the right: the cell's own `px-2` and this `pr-2`
/// add up to the `px-4` the toast had.
const String kToastWithActionClassName = 'py-0 pr-2';

/// Builds the slot recipe for the action of [MSToast].
///
/// Slots:
/// - `message` - the message column. It takes the box's vertical padding and
///   shrinks to its content while the text fits, and wraps in the width left
///   beside the action once it does not. `flex-initial` is a loose fit, so a
///   short message does not stretch the toast, and `min-w-0` lets the text
///   shrink instead of pushing the action out.
/// - `cell` - the tap target around the label, 44 px tall and at least 44 px
///   wide at every width, whose focus ring is `ring-inset`: the cell is as tall
///   as a one line toast, so an outside ring would paint beyond the box, white
///   on white. Its height is fixed rather than a minimum because the cell
///   centres its label with a column, and a column with only a minimum height
///   grows to the whole height an overlay offers it.
/// - `label` - the action text.
///
/// Variant axes:
/// - `variant`: `info` | `success` | `warning` | `error` (default `info`), the
///   tone of the toast the action sits on. `info` reads as a primary text
///   action on the surface; the three coloured tones keep the white of their
///   message, since a primary label would not read on a green or red fill.
Map<String, String> toastActionRecipe({
  Map<String, String?>? variants,
  Map<String, String>? classNames,
}) {
  const recipe = WindSlotRecipe(
    slots: {
      'message': 'flex-initial min-w-0 py-3',
      'cell':
          'flex flex-col justify-center items-center h-11 min-w-11 px-2 '
          'rounded-md transition-colors focus:ring-2 focus:ring-inset',
      'label': 'text-sm font-semibold',
    },
    variants: {
      kToastVariantAxis: {
        'info': {
          'cell':
              'hover:bg-surface-container-high focus:ring-primary-500 '
              'dark:focus:ring-primary-400',
          'label': 'text-primary',
        },
        'success': {
          'cell': 'hover:bg-white/15 focus:ring-white',
          'label': 'text-white',
        },
        'warning': {
          'cell': 'hover:bg-white/15 focus:ring-white',
          'label': 'text-white',
        },
        'error': {
          'cell': 'hover:bg-white/15 focus:ring-white',
          'label': 'text-white',
        },
      },
    },
    defaultVariants: {kToastVariantAxis: 'info'},
  );
  return recipe(variants: variants, classNames: classNames);
}
