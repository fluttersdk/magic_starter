import 'package:magic/magic.dart';

/// The tone axis key for the [MSStringValueList] recipe
/// (`StringValueListTone.<value>.name`).
const String kStringValueListToneAxis = 'tone';

/// Builds the [WindSlotRecipe] for the [MSStringValueList] component.
///
/// A chip list with a `tone` axis, so the same list renders an unremarkable
/// value, a cautionary one, or a severe one, using only the semantic tokens
/// [MagicStarterTokens.defaultAliases] already guarantees.
///
/// Tone -> token pair mapping:
/// - neutral:  `bg-surface-container-high` (a plain semantic surface, no
///   status colour; an unremarkable value is not itself a status)
/// - warn:     `bg-warning text-on-destructive`, mirroring `badge.recipe.dart`'s
///   own warning tone (white reads on amber the same way it reads on red)
/// - critical: `bg-destructive-container` for the tinted surface, paired with
///   a raw `text-red-700 dark:text-red-400` foreground. The alias contract
///   ships `bg-destructive-container` but no matching destructive TEXT role
///   (see `error_state.recipe.dart`'s own note on the same gap), so a
///   semantic-looking `text-destructive` token here would resolve to no
///   colour and silently drop instead of raising.
///
/// ### Slot structure
/// ```
/// root:   vertical stack of the chip row + the entry row
/// chips:  wrapping row of committed value chips
/// chip:   appended to WBadge's own base classes; tone controls this
/// remove: small inline ghost icon button that drops a chip
/// ```
const WindSlotRecipe stringValueListRecipe = WindSlotRecipe(
  slots: {
    'root': 'flex flex-col gap-2',
    // `flex-row` is not optional: a bare `flex` sets the display type and
    // leaves the axis at the default, so the chips would stack vertically.
    'chips': 'flex flex-row wrap gap-2',
    'chip': '',
    // size-9 rather than size-4. The glyph inside stays small; what grows is
    // the box around it, because the chips sit in a wrap row and a miss lands
    // on the neighbouring chip's remove control.
    'remove':
        'flex flex-row items-center justify-center size-9 shrink-0 rounded-full',
  },
  variants: {
    kStringValueListToneAxis: {
      'neutral': {'chip': 'bg-surface-container-high'},
      'warn': {'chip': 'bg-warning text-on-destructive'},
      'critical': {
        'chip': 'bg-destructive-container text-red-700 dark:text-red-400',
      },
    },
  },
  defaultVariants: {kStringValueListToneAxis: 'neutral'},
);
