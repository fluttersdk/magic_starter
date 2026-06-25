import 'package:magic/magic.dart';

/// The checkbox [WindRecipe] (const).
///
/// Returns the className for the [WCheckbox] outer box. The `checked:` state
/// prefix is driven by [WCheckbox]'s own active-states set; this recipe only
/// needs to supply the base box styling and the semantic token overrides.
const WindRecipe checkboxRecipe = WindRecipe(
  base: 'w-5 h-5 rounded border border-color-border '
      'checked:bg-primary checked:border-bg-primary '
      'disabled:opacity-50 disabled:cursor-not-allowed '
      'focus:ring-2 focus:ring-bg-primary',
);
