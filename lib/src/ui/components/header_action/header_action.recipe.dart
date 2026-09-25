import 'package:magic/magic.dart';

/// Builds the [WindRecipe] for the [MSHeaderAction] component's icon-only
/// form.
///
/// Only the icon-only form has a recipe. At `lg` and up the component
/// renders [MSButton], which owns its own styling; there is nothing here to
/// duplicate.
///
/// The box is a 44pt tap target, the accepted floor for a touch control. The
/// `intent` axis carries the only difference that matters at this size: a
/// primary action is the brand colour, a secondary one is muted.
WindRecipe headerActionRecipe() {
  return WindRecipe(
    base:
        'w-11 h-11 shrink-0 rounded-md flex items-center justify-center '
        'hover:bg-surface-container',
    variants: {
      'intent': {
        'primary': 'text-primary',
        'secondary': 'text-fg-muted hover:text-fg',
        'disabled': 'text-fg-disabled',
      },
    },
    defaultVariants: {'intent': 'primary'},
  );
}
