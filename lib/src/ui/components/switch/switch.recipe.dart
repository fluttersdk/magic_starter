import 'package:magic/magic.dart';

/// The switch track [WindRecipe] (const).
///
/// Returns the className for the [WSwitch] track (outer pill). The `checked:`
/// state prefix is driven by [WSwitch]'s active-states set; the recipe supplies
/// the base shape, the semantic token colors, and the thumb POSITION.
///
/// The thumb is a flex child of the track, so it moves left-to-right via
/// `justify-start` -> `checked:justify-end` (Wind supports flex alignment). It
/// deliberately does NOT use `translate-x-*`: Wind has no transform parser, so
/// a translate-based thumb would never move.
const WindRecipe switchTrackRecipe = WindRecipe(
  base:
      'w-11 h-6 rounded-full px-0.5 '
      'flex items-center justify-start checked:justify-end '
      'bg-surface-container-high checked:bg-primary '
      'disabled:opacity-50',
);

/// The switch thumb [WindRecipe] (const).
///
/// Returns the className for the [WSwitch] thumb (inner circle). Position is
/// owned by the track's `justify-*` (see [switchTrackRecipe]); the thumb only
/// supplies its shape and color.
const WindRecipe switchThumbRecipe = WindRecipe(
  base: 'w-5 h-5 rounded-full bg-surface shadow',
);
