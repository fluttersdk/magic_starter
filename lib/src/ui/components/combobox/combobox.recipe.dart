import 'package:magic/magic.dart';

/// Builds the slot recipe for [Combobox] from semantic tokens.
///
/// Shares the same slot shape as [selectRecipe] (trigger/popup/item) but the
/// trigger carries a search-input affordance (slightly different padding) and
/// the popup always includes an inline search field via `WSelect(searchable:
/// true)`.
///
/// Slots:
/// - `trigger` — the closed-state trigger with search-ready padding.
/// - `popup` — the dropdown overlay container.
/// - `item` — each option row inside the dropdown.
Map<String, String> comboboxRecipe({
  Map<String, String?>? variants,
  Map<String, String>? classNames,
}) {
  const recipe = WindSlotRecipe(
    slots: {
      'trigger':
          'w-full px-3 py-2 rounded-lg bg-surface-container-high border border-color-border text-fg flex items-center justify-between gap-2',
      'popup':
          'bg-surface border border-color-border rounded-lg shadow-md overflow-hidden',
      'item':
          'px-3 py-2 text-sm text-fg hover:bg-surface-container cursor-pointer',
    },
  );
  return recipe(variants: variants, classNames: classNames);
}
