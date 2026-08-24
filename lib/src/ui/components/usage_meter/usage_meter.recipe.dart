import 'package:magic/magic.dart';

/// The tone axis key for [usageMeterRecipe].
const String kUsageMeterToneAxis = 'tone';

/// Builds the [WindSlotRecipe] for the [MSUsageMeter] component.
///
/// A label, a used/limit readout, and a thin bar whose tone tracks how close
/// the resource is to its limit (success -> warning -> destructive).
///
/// The tone axis follows `BadgeTone`'s vocabulary, not a product's own status
/// language, and every token below is a key `MagicStarterTokens.defaultAliases`
/// guarantees (`text-fg`, `text-fg-muted`, `bg-surface-container-high`,
/// `bg-success`, `bg-warning`, `bg-destructive`); it resolves once a consumer
/// wires `WindThemeData(aliases: MagicStarterTokens.defaultAliases)` in,
/// exactly like `badge.recipe.dart` does.
///
/// ### Slot structure
/// ```
/// root    — flex-col, tight gap
/// head    — row: label (left) + used/limit readout (right), space-between
/// label   — text-sm font-medium fg
/// readout — font-mono text-xs tabular-nums muted
/// track   — h-1.5 full-width rounded rail, neutral fill, clips the bar
/// bar     — tone-coloured fill (width driven by a FractionallySizedBox)
/// ```
const WindSlotRecipe usageMeterRecipe = WindSlotRecipe(
  slots: {
    'root': 'flex flex-col gap-1.5',
    'head': 'flex flex-row items-center justify-between gap-2',
    'label': 'text-sm font-medium text-fg',
    'readout': 'font-mono text-xs tabular-nums text-fg-muted',
    'track':
        'h-1.5 w-full overflow-hidden rounded-full bg-surface-container-high',
    'bar': 'rounded-full',
  },
  variants: {
    kUsageMeterToneAxis: {
      'success': {'bar': 'bg-success'},
      'warning': {'bar': 'bg-warning'},
      'destructive': {'bar': 'bg-destructive'},
    },
  },
  defaultVariants: {kUsageMeterToneAxis: 'success'},
);
