import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_theme.dart';

/// Builds the slot recipe for [MSCombobox] from semantic tokens.
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
///
/// The padding, minimum height and type of the `trigger` come from [theme]
/// ([MagicStarterFieldTheme.selectSizeClassName], the same field as the select's
/// trigger); the widget passes `MagicStarter.fieldTheme`, and the default is the
/// stock look.
Map<String, String> comboboxRecipe({
  MagicStarterFieldTheme theme = const MagicStarterFieldTheme(),
  Map<String, String?>? variants,
  Map<String, String>? classNames,
}) {
  final recipe = WindSlotRecipe(
    slots: {
      'trigger':
          'w-full px-3 ${theme.selectSizeClassName} rounded-lg bg-surface-container-high border '
          'border-color-border text-fg flex items-center justify-between gap-2',
      'popup':
          'bg-surface border border-color-border rounded-lg shadow-md overflow-hidden',
      'item':
          'px-3 py-2 text-sm text-fg hover:bg-surface-container cursor-pointer',
    },
  );
  return recipe(variants: variants, classNames: classNames);
}
