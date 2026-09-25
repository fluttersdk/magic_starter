import 'package:magic/magic.dart';

/// Builds the [WindSlotRecipe] for the [MSKeyValueEditor] component.
///
/// A vertical stack of key/value input rows, each with a square ghost remove
/// control, plus a trailing add button (rendered by the component via
/// [MSButton]).
///
/// ### Slot structure
/// ```
/// root:   vertical stack of rows + the add button
/// remove: square ghost icon button that drops a row
/// ```
const WindSlotRecipe keyValueEditorRecipe = WindSlotRecipe(
  slots: {
    'root': 'flex flex-col gap-2',
    // size-11 is the 44dp tap-target floor `header_action`'s icon-only form
    // already holds; this row has the height to spare, unlike the chip
    // remove in `string_value_list`, which does not.
    'remove':
        'flex flex-row size-11 shrink-0 items-center justify-center '
        'rounded-md text-fg-muted hover:bg-surface-container hover:text-fg',
  },
);
