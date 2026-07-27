import 'package:magic/magic.dart';

/// Builds the [WindSlotRecipe] for the MSUpgradeNudge component.
///
/// The source frames the banner with `border-ai-soft` + a `from-ai-soft/50
/// to-surface` gradient wash. Wind has no gradient and no `border-ai-soft`
/// token, and a solid `bg-ai-soft` fill would over-saturate AND hide the
/// equally-ai-soft lock tile. So the banner fill is NEUTRAL
/// (`bg-surface-container` + neutral border) and the AI signal is carried by
/// the saturated ai-soft lock tile.
///
/// ### Slot structure
/// ```
/// root    - neutral card banner (rounded-xl, border, padding)
/// tile    - size-8 ai-soft rounded tile holding the lock glyph
/// message - text-sm font-medium fg (the gated-feature headline)
/// sub     - text-xs muted ("Available on <plan> and up.")
/// ```
const WindSlotRecipe upgradeNudgeRecipe = WindSlotRecipe(
  slots: {
    'root': 'rounded-xl border border-color-border bg-surface-container p-4',
    'tile':
        'flex flex-row size-8 shrink-0 items-center justify-center rounded-lg bg-ai-soft',
    'message': 'text-sm font-medium text-fg',
    'sub': 'text-xs text-fg-muted',
  },
);
