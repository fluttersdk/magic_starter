import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'segmented_control.recipe.dart';

/// A tab-bar-style segmented control component for Magic Starter.
///
/// Renders a horizontal row of segments where exactly one is active at a time.
/// The active segment activates the `selected:` state prefix in its className
/// so callers can supply `selected:bg-surface selected:text-fg` tokens (the
/// defaults come from the slot recipe).
///
/// ### Example Usage:
///
/// ```dart
/// SegmentedControl<String>(
///   options: const ['Monthly', 'Annual'],
///   selectedIndex: _selected,
///   onChanged: (i) => setState(() => _selected = i),
/// )
/// ```
@immutable
class SegmentedControl<T> extends StatelessWidget {
  /// The label displayed for each segment, in display order.
  final List<String> options;

  /// The zero-based index of the currently selected segment.
  final int selectedIndex;

  /// Called when the user taps a segment, with its zero-based index.
  final ValueChanged<int>? onChanged;

  /// Visual size variant; defaults to [SegmentedControlSize.md].
  final SegmentedControlSize size;

  /// Per-slot className overrides appended after the recipe output.
  final Map<String, String>? classNames;

  /// Creates a [SegmentedControl] widget.
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    this.onChanged,
    this.size = SegmentedControlSize.md,
    this.classNames,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Resolve slot classNames from the recipe for the requested size.
    final slots = segmentedControlRecipe(
      variants: {kSegmentedControlSizeAxis: size.name},
      classNames: classNames,
    );

    // 2. Build the root container with a segment per option.
    return WDiv(
      className: slots['root'],
      children: List<Widget>.generate(options.length, (index) {
        return _buildSegment(index, slots['item'] ?? '');
      }),
    );
  }

  /// Builds a single segment at [index], activating the `selected:` state for
  /// the currently selected index.
  Widget _buildSegment(int index, String itemClassName) {
    final bool isSelected = index == selectedIndex;
    final Set<String> segmentStates = {
      if (isSelected) 'selected',
    };

    return WAnchor(
      onTap: () => onChanged?.call(index),
      states: segmentStates,
      child: WDiv(
        className: itemClassName,
        states: segmentStates,
        child: WText(options[index]),
      ),
    );
  }
}
