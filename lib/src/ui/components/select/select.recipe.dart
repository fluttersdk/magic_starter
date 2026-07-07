import 'package:magic/magic.dart';

/// Builds the slot recipe for [MSSelect] from semantic tokens.
///
/// Slots:
/// - `trigger` — the closed-state trigger button.
/// - `popup` — the dropdown overlay container.
/// - `item` — each option row inside the dropdown.
///
/// The recipe reads semantic token aliases (Step 7) so a `design:sync`-generated
/// theme override re-skins the entire select without touching this file.
Map<String, String> selectRecipe({
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
