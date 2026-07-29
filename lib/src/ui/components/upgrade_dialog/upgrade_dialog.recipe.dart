import 'package:magic/magic.dart';

/// Builds the [WindSlotRecipe] for the MSUpgradeDialog component.
///
/// Sibling of `upgrade_nudge.recipe.dart`: same neutral fill plus tinted lock
/// tile idiom, sized for a dialog body rather than an inline banner. The
/// caller supplies the modal chrome (barrier, positioning, surrounding card),
/// so this recipe carries no border or background of its own.
///
/// Every token here is one the starter's own theme guarantees; see the note in
/// the sibling recipe for why an `ai-*` token would render nothing.
///
/// ### Slot structure
/// ```
/// root    - column layout, generous gap (the modal wrapper supplies padding)
/// tile    - size-10 tinted rounded tile holding the lock glyph
/// message - text-base font-medium fg (the backend's gated-feature sentence)
/// sub     - text-sm muted ("Available on <plan> and up.")
/// actions - trailing row holding the dismiss + upgrade buttons
/// ```
const WindSlotRecipe upgradeDialogRecipe = WindSlotRecipe(
  slots: {
    'root': 'flex flex-col items-start gap-4',
    'tile':
        'flex flex-row size-10 shrink-0 items-center justify-center rounded-lg bg-primary-container',
    'message': 'text-base font-medium text-fg',
    'sub': 'text-sm text-fg-muted',
    'actions': 'flex flex-row justify-end gap-3 self-stretch',
  },
);
