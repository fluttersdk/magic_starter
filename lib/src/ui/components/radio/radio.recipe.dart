import 'package:magic/magic.dart';

/// The radio shell [WindRecipe] (const).
///
/// Returns the className for the [WRadio] outer ring. The `selected:` and
/// `disabled:` state prefixes are driven by [WRadio]'s active-states set.
///
/// We MUST supply explicit token classNames here (including the `selected:`
/// overrides) because [WRadio] ships default tone tokens (`border-gray-300`,
/// `bg-blue-500`) that would bypass semantic aliases. Passing a className
/// entirely overrides the wind primitive defaults.
const WindRecipe radioShellRecipe = WindRecipe(
  base:
      'w-5 h-5 rounded-full border border-color-border '
      'items-center justify-center '
      'selected:border-color-border '
      'selected:bg-primary-container '
      'disabled:opacity-50 disabled:cursor-not-allowed '
      'hover:border-bg-primary',
);

/// The radio indicator [WindRecipe] (const).
///
/// Returns the className for the filled center dot shown when selected.
const WindRecipe radioIndicatorRecipe = WindRecipe(
  base: 'w-2.5 h-2.5 rounded-full bg-primary',
);
