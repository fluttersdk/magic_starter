import 'package:magic/magic.dart';

/// Builds the [WindSlotRecipe] for the MSUpgradeNudge component.
///
/// The banner fill is NEUTRAL (`bg-surface-container` + a neutral border) and
/// the signal is carried by the tinted lock tile, so the two do not compete.
///
/// Every token here is one the starter's own theme guarantees
/// (`magic_starter_tokens.dart`). The tile deliberately does NOT use an `ai-*`
/// token: that family is a consumer-specific supplement, not part of the
/// semantic role set `design:sync` emits, and Wind drops an unknown token
/// silently, so referencing one from a shared component renders no background
/// at all in every app that has not hand-authored it.
///
/// ### Slot structure
/// ```
/// root    - neutral card banner (rounded-xl, border, padding)
/// tile    - size-8 tinted rounded tile holding the lock glyph
/// message - text-sm font-medium fg (the gated-feature headline)
/// sub     - text-xs muted ("Available on <plan> and up.")
/// ```
const WindSlotRecipe upgradeNudgeRecipe = WindSlotRecipe(
  slots: {
    'root': 'rounded-xl border border-color-border bg-surface-container p-4',
    'tile':
        'flex flex-row size-8 shrink-0 items-center justify-center rounded-lg bg-primary-container',
    'message': 'text-sm font-medium text-fg',
    'sub': 'text-xs text-fg-muted',
  },
);
