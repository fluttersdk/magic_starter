import 'package:magic/magic.dart';

/// The switch track [WindRecipe] (const).
///
/// Returns the className for the [WSwitch] track (outer pill). The `checked:`
/// state prefix is driven by [WSwitch]'s active-states set; the recipe only
/// supplies base shape and semantic token color overrides.
const WindRecipe switchTrackRecipe = WindRecipe(
  base: 'w-11 h-6 rounded-full border-2 '
      'bg-surface-container-high border-color-border '
      'checked:bg-primary checked:border-bg-primary '
      'disabled:opacity-50 disabled:cursor-not-allowed '
      'focus:ring-2 focus:ring-bg-primary',
);

/// The switch thumb [WindRecipe] (const).
///
/// Returns the className for the [WSwitch] thumb (inner circle).
const WindRecipe switchThumbRecipe = WindRecipe(
  base: 'w-4 h-4 rounded-full bg-surface '
      'translate-x-0 checked:translate-x-5 '
      'shadow transition-transform',
);
