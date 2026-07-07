import 'package:magic/magic.dart';

/// The variant axis key for the typography recipe
/// (`TypographyVariant.<value>.name`).
const String kTypographyVariantAxis = 'variant';

/// Builds the typography [WindRecipe] using semantic tokens.
///
/// The recipe is a top-level const because the typography component has no
/// theme-override hook; variants read from semantic tokens and scale values.
///
/// Emission order: `base ++ variant-classes`.
///
/// Variant -> className mapping (all inherit `text-fg` from base):
/// - h1: `text-4xl font-bold leading-tight`
/// - h2: `text-3xl font-bold leading-tight`
/// - h3: `text-2xl font-semibold leading-snug`
/// - body: `text-base font-normal leading-relaxed`
/// - caption: `text-sm font-normal text-fg-muted`
const WindRecipe typographyRecipe = WindRecipe(
  base: 'text-fg',
  variants: {
    kTypographyVariantAxis: {
      'h1': 'text-4xl font-bold leading-tight',
      'h2': 'text-3xl font-bold leading-tight',
      'h3': 'text-2xl font-semibold leading-snug',
      'body': 'text-base font-normal leading-relaxed',
      'caption': 'text-sm font-normal text-fg-muted',
    },
  },
  defaultVariants: {
    kTypographyVariantAxis: 'body',
  },
);
