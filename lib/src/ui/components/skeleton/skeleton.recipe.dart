import 'package:magic/magic.dart';

/// The shape axis key for the skeleton recipe (`SkeletonShape.<value>.name`).
const String kSkeletonShapeAxis = 'shape';

/// Builds the skeleton [WindRecipe] using semantic tokens.
///
/// The recipe is a top-level const because the skeleton has no theme-override
/// hook.
///
/// Base carries the pulse animation and muted surface fill via the semantic
/// token `bg-surface-container-high` (the nearest equivalent to `bg-muted` —
/// there is no `bg-muted` alias in [MagicStarterTokens.defaultAliases]).
///
/// Emission order: `base ++ shape-variant`.
///
/// Shape -> additional className:
/// - block:  `rounded-md` — rectangular block placeholder
/// - text:   `rounded`   — short inline text line placeholder
/// - circle: `rounded-full` — avatar / icon circle placeholder
const WindRecipe skeletonRecipe = WindRecipe(
  base: 'animate-pulse bg-surface-container-high',
  variants: {
    kSkeletonShapeAxis: {
      'block': 'rounded-md',
      'text': 'rounded',
      'circle': 'rounded-full',
    },
  },
  defaultVariants: {
    kSkeletonShapeAxis: 'block',
  },
);
