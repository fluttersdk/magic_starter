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
