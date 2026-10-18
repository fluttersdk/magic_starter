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
///
/// The `focus:` ring is an outline painted around the track, never part of its
/// box, so a keyboard user landing on the switch moves nothing. The offset keeps
/// it apart from a `checked:bg-primary` track of the same colour.
const WindRecipe switchTrackRecipe = WindRecipe(
  base:
      'w-11 h-6 rounded-full px-0.5 '
      'flex items-center justify-start checked:justify-end '
      'bg-surface-container-high checked:bg-primary '
      'focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 '
      'dark:focus:ring-primary-400 '
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

/// The [WindRecipe] for the tappable area around an unlabelled [MSSwitch].
///
/// `min-h-11 lg:min-h-0` is the touch target: 44 px tall on a phone, around a
/// 24 px track that is still painted at 24 px, and nothing extra from `lg` up.
const WindRecipe switchHitAreaRecipe = WindRecipe(
  base: 'flex flex-row items-center min-h-11 lg:min-h-0',
);

/// The [WindRecipe] for the tappable area around a labelled [MSSwitch].
///
/// The same touch target as [switchHitAreaRecipe]. The track and the label
/// inside it are laid out by the switch itself, centred on one line, so this
/// only sets the height.
const WindRecipe switchLabelledHitAreaRecipe = WindRecipe(
  base: 'min-h-11 lg:min-h-0',
);

/// The className of the visible label text inside an [MSSwitch].
const String switchLabelClassName = 'text-sm text-fg';
