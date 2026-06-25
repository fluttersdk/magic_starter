import 'package:magic/magic.dart';

/// Builds the slot recipe for [Tabs] from semantic tokens.
///
/// Slots:
/// - `list` — the horizontal tab-list row with the border separator.
/// - `tab` — each individual tab item (supports `selected:` state prefix).
/// - `panel` — the content panel shown below the tab list.
///
/// The `selected:` state tokens on `tab` activate only on the currently
/// selected tab, driven by [WTabs]'s state injection. The caller may extend
/// the per-slot classNames via the [classNames] override map.
Map<String, String> tabsRecipe({
  Map<String, String?>? variants,
  Map<String, String>? classNames,
}) {
  const recipe = WindSlotRecipe(
    slots: {
      'list': 'flex flex-row border-b border-color-border',
      'tab':
          'px-4 py-2 text-sm font-medium text-fg-muted cursor-pointer selected:text-fg selected:border-b-2 selected:border-color-border',
      'panel': 'pt-4',
    },
  );
  return recipe(variants: variants, classNames: classNames);
}
