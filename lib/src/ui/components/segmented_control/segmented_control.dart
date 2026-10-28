import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';
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
/// ### The selected segment in a scroller
///
/// A row wider than a horizontal scroller around it (the `overflow-x-auto` root
/// override, or a `SingleChildScrollView` the host wraps it in) can leave the
/// active segment clipped or out of sight. When the control first mounts, and
/// whenever [selectedIndex] changes, it scrolls that scroller just far enough to
/// show the segment whole, once the frame is laid out and without animation.
/// Nothing moves when the segment is already in view, on a rebuild that keeps
/// the same [selectedIndex] (the user's own scrolling is not undone), without a
/// horizontal scroller above the control, or for an index that names no segment.
///
/// Only one scroller is ever asked: the one nearest to the segment, of either
/// axis, and only when it is horizontal. Under a vertical list or page nothing
/// moves, because the reveal would measure against that vertical viewport. A
/// horizontal scroller moves when it is the root's own `overflow-x-auto`, or
/// when the control is everything it scrolls (its content is as wide as the
/// control: no padding, no sibling beside it). A page view that holds the
/// control, or a strip several controls share, belongs to the host, and the
/// reveal would snap a page mid-drag or drag a whole table along.
/// `Scrollable.ensureVisible` is not used because it walks every scrollable
/// above the segment: it would also put the control at the top edge of the
/// page's vertical scroll view, or pull the page down to a control that sits
/// below the fold.
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
class MSSegmentedControl<T> extends StatefulWidget {
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
  State<MSSegmentedControl<T>> createState() => _MSSegmentedControlState<T>();

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
}

/// State of [MSSegmentedControl]: builds the row and keeps the selected segment
/// in view of a horizontal scroller around it.
class _MSSegmentedControlState<T> extends State<MSSegmentedControl<T>> {
  /// One key per segment, so the selected one can be found once the frame is
  /// laid out. Grown in [build] to the number of options.
  final List<GlobalKey> _segmentKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _revealSelectedAfterFrame();
  }

  @override
  void didUpdateWidget(MSSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex == widget.selectedIndex) return;

    _revealSelectedAfterFrame();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Resolve slot classNames from the recipe for the requested size.
    final slots = segmentedControlRecipe(
      theme: MagicStarter.fieldTheme,
      variants: {kSegmentedControlSizeAxis: widget.size.name},
      classNames: widget.classNames,
    );

    // 2. Decide whether the segments may shrink: only a flex row with a bounded
    //    width divides a horizontal share among them.
    final String rootClassName = slots['root'] ?? '';
    final bool shrinkSegments = MSSegmentedControl._rootDividesWidth(
      rootClassName,
    );

    // 3. Keep a key per segment for the reveal.
    while (_segmentKeys.length < widget.options.length) {
      _segmentKeys.add(GlobalKey());
    }

    // 4. Build the root container with a segment per option, each one free to
    //    shrink to an equal share of the row when the labels do not fit.
    return WDiv(
      className: rootClassName,
      children: List<Widget>.generate(widget.options.length, (index) {
        final Widget segment = _buildSegment(
          index,
          slots['item'] ?? '',
          slots['hit'] ?? '',
        );
        if (!shrinkSegments) return segment;

        return Flexible(fit: FlexFit.loose, child: segment);
      }),
    );
  }

  /// Scrolls the selected segment into view once this frame has been laid out.
  ///
  /// The scroller's extent is only known after layout, so this waits for the
  /// frame that mounted or rebuilt the row.
  void _revealSelectedAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  /// Shows the selected segment whole in the horizontal [Scrollable] around it.
  ///
  /// Does nothing when the scroller nearest to the segment is not a horizontal
  /// one this control may move, when the index names no segment, or when the
  /// segment is already in view.
  void _revealSelected() {
    // 1. The control may be gone, or the index may name no segment (-1 is a
    //    row with nothing selected).
    final int index = widget.selectedIndex;
    if (!mounted || index < 0 || index >= _segmentKeys.length) return;

    final BuildContext? segment = _segmentKeys[index].currentContext;
    if (segment == null) return;

    // 2. Ask the nearest scroller of EITHER axis, and go on only when it is
    //    horizontal. ScrollPosition.ensureVisible measures against the viewport
    //    nearest to the segment, whatever the position's axis: past a vertical
    //    list, `Scrollable.maybeOf(axis: horizontal)` would hand back the strip
    //    beyond it and the list's vertical offset would be jumped onto the
    //    strip.
    final ScrollableState? scroller = Scrollable.maybeOf(segment);
    final RenderObject? target = segment.findRenderObject();
    if (scroller == null || target == null) return;
    if (scroller.position.axis != Axis.horizontal) return;

    // 3. Leave a scroller that is the host's own business alone.
    if (!_mayMove(scroller)) return;

    // 4. Each keep-visible policy moves the strip in one direction only, and
    //    only when the segment lies past that edge, so a segment already in view
    //    stays where it is. Without a duration the jump happens right here, and
    //    the second call sees the position the first one left.
    for (final ScrollPositionAlignmentPolicy policy in const [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      scroller.position.ensureVisible(target, alignmentPolicy: policy);
    }
  }

  /// Whether this control may move [scroller]: it is the control's own, or the
  /// control is all it scrolls.
  ///
  /// A scroller inside the control is the root's `overflow-x-auto`, and moving
  /// it is the point. One outside is the host's, and jumping it would also
  /// snap a page view page mid-drag, or drag a table strip along each time one
  /// of its rows changes its selection. What tells a strip wrapped around the
  /// control from those is its content: the control fills it when its extent
  /// (the scrollable range plus the viewport) is the control's own width, within
  /// a pixel of rounding. A strip that pads the control or holds a sibling has a
  /// larger extent and counts as the host's.
  bool _mayMove(ScrollableState scroller) {
    final bool isOwn =
        context.findAncestorStateOfType<ScrollableState>() != scroller;
    if (isOwn) return true;

    final ScrollPosition position = scroller.position;
    final double content =
        position.maxScrollExtent + position.viewportDimension;

    return (content - context.size!.width).abs() <= 1;
  }

  /// Builds a single segment at [index], activating the `selected:` state for
  /// the currently selected index.
  ///
  /// The pill sits in a [hitClassName] cell that is 44 px tall below `lg`, so
  /// the anchor (and the semantics node a tap target check measures) is the
  /// cell while the painted pill keeps its own height.
  Widget _buildSegment(int index, String itemClassName, String hitClassName) {
    final bool isSelected = index == widget.selectedIndex;
    final Set<String> segmentStates = {if (isSelected) 'selected'};

    return WAnchor(
      key: _segmentKeys[index],
      onTap: () => widget.onChanged?.call(index),
      states: segmentStates,
      child: WDiv(
        className: hitClassName,
        child: WDiv(
          className: itemClassName,
          states: segmentStates,
          child: WText(widget.options[index]),
        ),
      ),
    );
  }
}
