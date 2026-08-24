import 'package:magic/magic.dart';

/// Size axis key for [MSSegmentedControl].
const String kSegmentedControlSizeAxis = 'size';

/// Visual size variants for [MSSegmentedControl].
enum SegmentedControlSize {
  /// Compact size: smaller padding and text.
  sm,

  /// Default size: standard padding and text.
  md,
}

/// Builds the slot recipe for [MSSegmentedControl] from semantic tokens.
///
/// Slots:
/// - `root` — the outer container row.
/// - `item` — each individual segment button.
///
/// Variant axes:
/// - `size`: `sm` | `md` (default `md`).
Map<String, String> segmentedControlRecipe({
  Map<String, String?>? variants,
  Map<String, String>? classNames,
}) {
  const recipe = WindSlotRecipe(
    slots: {
      'root':
          'flex flex-row items-center rounded-lg bg-surface-container-high '
          'p-1 gap-1',
      // `text-center` keeps a label that wrapped onto a second line (the
      // segment is capped at an equal share of a row too narrow for its
      // labels) centred under the first, whatever the caller aligns.
      'item':
          'px-3 py-1.5 rounded-md text-sm font-medium text-center text-fg-muted cursor-pointer selected:bg-surface selected:text-fg selected:shadow-sm transition-colors',
    },
    variants: {
      kSegmentedControlSizeAxis: {
        'sm': {'root': '', 'item': 'px-2 py-1 text-sm'},
        'md': {'root': '', 'item': 'px-3 py-1.5 text-sm'},
      },
    },
    defaultVariants: {kSegmentedControlSizeAxis: 'md'},
  );
  return recipe(variants: variants, classNames: classNames);
}
