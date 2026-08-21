import 'package:magic/magic.dart';

/// Builds the slot recipe for [MSTabs] from semantic tokens.
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
      // The selected underline is the BRAND colour, not `border-color-border`:
      // that is the same token as the `list` rule the tabs sit on, so an active
      // tab used to mark itself with a thicker length of the very line it was
      // sitting on. It read as a grey smudge rather than a selection.
      'tab':
          'px-4 py-2 text-sm font-medium text-fg-muted cursor-pointer selected:text-fg selected:border-b-2 selected:border-primary-600 dark:selected:border-primary-500',
      'panel': 'pt-4',
    },
  );
  return recipe(variants: variants, classNames: classNames);
}
