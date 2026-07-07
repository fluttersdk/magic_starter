import 'package:magic/magic.dart';

/// Builds the slot recipe for [MSAccordion] from semantic tokens.
///
/// Slots:
/// - `root` — outer container holding all accordion items.
/// - `item` — each individual accordion item (wrapper for header+panel).
/// - `header` — the header row containing [trigger].
/// - `trigger` — the tappable title row (WAnchor-backed in the component).
/// - `panel` — the collapsible content area, shown only when expanded.
///
/// There are no variant axes in v1; the slot classNames come entirely from
/// semantic tokens. Callers may override individual slots via [classNames].
Map<String, String> accordionRecipe({
  Map<String, String?>? variants,
  Map<String, String>? classNames,
}) {
  const recipe = WindSlotRecipe(
    slots: {
      'root': 'w-full border border-color-border rounded-lg overflow-hidden',
      'item': 'bg-surface',
      'header': 'flex flex-row items-center',
      'trigger':
          'flex flex-row items-center justify-between px-4 py-3 text-sm font-medium text-fg cursor-pointer hover:bg-surface-container',
      'panel': 'px-4 pb-4 text-sm text-fg-muted',
    },
  );
  return recipe(variants: variants, classNames: classNames);
}
