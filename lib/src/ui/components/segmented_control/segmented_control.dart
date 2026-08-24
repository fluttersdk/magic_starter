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
/// ### Behaviour on a narrow surface
///
/// Every segment is a loosely fitted [Flexible], so the row adapts instead of
/// overflowing: a segment keeps its content width while the labels fit, and is
/// capped at an equal share of the row once they do not, at which point its
/// label wraps onto another line. Labels are never shortened from the right,
/// because a segment can carry a localised sentence (`Annual · save ~15%`) and
/// an ellipsis would cut it before its meaning is complete.
///
/// The fit is [FlexFit.loose] rather than [Expanded] on purpose. Tight fits
/// would stretch the control across the full width of any bounded parent, and
/// would assert inside a horizontally unbounded one (a scrolling row, an
/// intrinsic-width measure); loose fitting shrink-wraps in the first case and
/// falls back to content width in the second.
///
/// A caller that overrides the root slot into a wrapping, vertical, or
/// horizontally scrolling container (`classNames: {'root': 'wrap'}`,
/// `flex-col`, `overflow-x-auto`) keeps the older behaviour: the segments stay
/// at content width and the container places them, since only a horizontal
/// flex over a bounded width can hand a segment a share of it.
///
/// ### Example Usage:
///
/// ```dart
/// MSSegmentedControl<String>(
///   options: const ['Monthly', 'Annual'],
///   selectedIndex: _selected,
///   onChanged: (i) => setState(() => _selected = i),
/// )
/// ```
@immutable
class MSSegmentedControl<T> extends StatelessWidget {
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

  /// Creates a [MSSegmentedControl] widget.
  const MSSegmentedControl({
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

    // 2. Decide whether the segments may shrink: only a flex row with a bounded
    //    width divides a horizontal share among them.
    final String rootClassName = slots['root'] ?? '';
    final bool shrinkSegments = _rootDividesWidth(rootClassName);

    // 3. Build the root container with a segment per option, each one free to
    //    shrink to an equal share of the row when the labels do not fit.
    return WDiv(
      className: rootClassName,
      children: List<Widget>.generate(options.length, (index) {
        final Widget segment = _buildSegment(index, slots['item'] ?? '');
        if (!shrinkSegments) return segment;

        return Flexible(fit: FlexFit.loose, child: segment);
      }),
    );
  }

  /// Wind display tokens, in the order the parser knows them.
  static const Set<String> _displayTokens = {
    'flex',
    'flex-wrap',
    'wrap',
    'grid',
    'block',
  };

  /// Wind flex-direction tokens.
  static const Set<String> _directionTokens = {
    'flex-row',
    'flex-row-reverse',
    'flex-col',
    'flex-col-reverse',
  };

  /// Wind tokens that make the root's horizontal axis scrollable, and so
  /// unbounded: there is no width to divide inside one.
  static const Set<String> _scrollsHorizontallyTokens = {
    'overflow-auto',
    'overflow-scroll',
    'overflow-x-auto',
    'overflow-x-scroll',
  };

  /// Whether [className] leaves the root a horizontal flex over a bounded
  /// width, the one container that can hand a segment a share of it.
  ///
  /// The recipe's own root is such a row, but a caller may append an override:
  /// wind's `wrap` (and its `flex-wrap` alias) builds a `Wrap`, which runs a
  /// segment onto a second line rather than shrinking it and rejects
  /// [Flexible] outright; `flex-col` builds a `Column`, where a share of the
  /// main axis is a share of the HEIGHT; and `overflow-x-auto` scrolls the row,
  /// which is the same as having no width to share. All three keep their
  /// segments at content width.
  ///
  /// Wind resolves the last unprefixed token of each family, so this reads the
  /// list the same way. A prefixed token (`md:wrap`) is conditional on a
  /// breakpoint that no build pass knows, and is read as leaving the row alone.
  static bool _rootDividesWidth(String className) {
    String display = '';
    String direction = 'flex-row';

    for (final String token in className.split(RegExp(r'\s+'))) {
      if (token.contains(':')) continue;
      if (_scrollsHorizontallyTokens.contains(token)) return false;
      if (_displayTokens.contains(token)) display = token;
      if (_directionTokens.contains(token)) direction = token;
    }

    return display == 'flex' && direction.startsWith('flex-row');
  }

  /// Builds a single segment at [index], activating the `selected:` state for
  /// the currently selected index.
  Widget _buildSegment(int index, String itemClassName) {
    final bool isSelected = index == selectedIndex;
    final Set<String> segmentStates = {if (isSelected) 'selected'};

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
