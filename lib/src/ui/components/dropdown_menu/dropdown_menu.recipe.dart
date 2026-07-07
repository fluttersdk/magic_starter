import 'package:magic/magic.dart';

/// The [DropdownMenu] popover-panel [WindRecipe] (const).
///
/// The base carries the default panel styling with semantic alias tokens. A
/// caller `className` is APPENDED after the base (parser last-wins resolves
/// conflicts per family), so it refines the default rather than replacing it.
const WindRecipe dropdownMenuPanelRecipe = WindRecipe(
  base: 'min-w-40 bg-surface border border-color-border rounded-lg shadow-lg '
      'py-1 overflow-hidden',
);

/// The [DropdownMenu] active-item [WindRecipe] (const).
///
/// Applied to each enabled item's container. A per-item `className` appends
/// after the base so callers refine an individual row without losing the base.
const WindRecipe dropdownMenuItemRecipe = WindRecipe(
  base: 'flex flex-row items-center gap-2 px-4 py-2 text-sm text-fg '
      'hover:bg-surface-container',
);

/// The [DropdownMenu] disabled-item [WindRecipe] (const).
///
/// Applied to each disabled item's container (muted, non-interactive). A
/// per-item `className` appends after the base.
const WindRecipe dropdownMenuItemDisabledRecipe = WindRecipe(
  base: 'flex flex-row items-center gap-2 px-4 py-2 text-sm text-fg-disabled',
);
