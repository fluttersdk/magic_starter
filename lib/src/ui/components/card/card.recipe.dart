import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_theme.dart';

/// The variant axis key for the card recipe (`CardVariant.<value>.name`).
const String kCardVariantAxis = 'variant';

/// The padding axis key for the card recipe (`padded` / `noPadding`).
const String kCardPaddingAxis = 'padding';

/// The `padding` axis value for the default padded body.
const String kCardPaddingPadded = 'padded';

/// The `padding` axis value for the full-bleed (no body padding) body.
const String kCardPaddingNoPadding = 'noPadding';

/// Builds the card [WindRecipe] from a [MagicStarterCardTheme].
///
/// The recipe is theme-driven (not a top-level const) because the card tone,
/// radius, and padding classNames are all overridable through
/// `MagicStarter.useCardTheme()` and the test suite swaps them per case. The
/// emission order reproduces the original `_defaultClassName` interpolation
/// VERBATIM so the recipe output stays byte-identical to the pre-migration
/// widget for every variant x padding combination:
///
/// ```text
/// w-full {variantClass} {borderRadius} {paddingTail}
/// ```
///
/// where `paddingTail` is `{paddingClassName} flex flex-col gap-4` in the
/// padded mode and `overflow-hidden flex flex-col` in the full-bleed mode. The
/// border-radius is folded into each variant value (rather than its own axis)
/// so it sits immediately after the tone class, matching the original order.
WindRecipe buildCardRecipe(MagicStarterCardTheme theme) {
  return WindRecipe(
    base: 'w-full',
    variants: {
      kCardVariantAxis: {
        'surface': '${theme.surfaceClassName} ${theme.borderRadius}',
        'inset': '${theme.insetClassName} ${theme.borderRadius}',
        'elevated': '${theme.elevatedClassName} ${theme.borderRadius}',
      },
      kCardPaddingAxis: {
        kCardPaddingPadded: '${theme.paddingClassName} flex flex-col gap-4',
        kCardPaddingNoPadding: 'overflow-hidden flex flex-col',
      },
    },
    defaultVariants: {
      kCardVariantAxis: 'surface',
      kCardPaddingAxis: kCardPaddingPadded,
    },
  );
}
