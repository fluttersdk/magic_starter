import 'package:magic/magic.dart';

/// The [MSTooltip] panel [WindRecipe] (const).
///
/// The base carries the default panel styling using semantic alias tokens
/// (`bg-surface-container-high`, `text-fg`, `border-color-border`) so the
/// tooltip re-skins with `MagicStarterTokens` and `design:sync` output, in both
/// light and dark theme, with no hardcoded palette utilities.
///
/// A caller `className` is APPENDED after the base (parser last-wins resolves
/// conflicts per family), so it refines the default rather than replacing it.
const WindRecipe tooltipPanelRecipe = WindRecipe(
  base:
      'bg-surface-container-high text-fg border border-color-border '
      'text-xs px-2 py-1 rounded max-w-xs',
);
