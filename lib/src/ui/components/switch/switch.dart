import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
// intl's TextDirection would shadow the one Directionality hands out.
import 'package:magic/magic.dart' hide TextDirection;

import 'switch.recipe.dart';

/// A reusable toggle switch component for Magic Starter forms.
///
/// Wraps [WSwitch] with [WindRecipe] tokens that apply semantic colors so the
/// track and thumb follow the brand without hardcoded values.
///
/// ### Usage
///
/// ```dart
/// MSSwitch(
///   value: _enabled,
///   onChanged: (v) => setState(() => _enabled = v),
/// )
/// ```
///
/// ### Tap target
///
/// Below `lg` the switch sits in a 44 px tall hit area (the iOS minimum) around
/// its 24 px track, which is still painted at 24 px. The area, and [label] when
/// there is one, toggle the switch like the track does.
@immutable
class MSSwitch extends StatelessWidget {
  /// Whether the switch is on.
  final bool value;

  /// Called when the switch value changes.
  final ValueChanged<bool>? onChanged;

  /// Whether the switch is disabled.
  final bool disabled;

  /// Optional caller className for the track, appended after the recipe output.
  final String? className;

  /// Optional caller className for the thumb, appended after the recipe output.
  final String? thumbClassName;

  /// Accessible label for the switch (required for icon-only usage).
  final String? semanticLabel;

  /// Optional visible label beside the track.
  ///
  /// Part of the tap target (tapping it toggles the switch) and the switch's
  /// accessible name unless [semanticLabel] says otherwise. Null renders the
  /// track alone.
  final String? label;

  /// Creates a [MSSwitch].
  const MSSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.disabled = false,
    this.className,
    this.thumbClassName,
    this.semanticLabel,
    this.label,
  });

  /// Resolves the track className from the recipe with the caller className
  /// appended last.
  String _resolveClassName() => switchTrackRecipe(className: className);

  /// Resolves the thumb className from the recipe with the caller className
  /// appended last.
  String _resolveThumbClassName() =>
      switchThumbRecipe(className: thumbClassName);

  @override
  Widget build(BuildContext context) {
    final bool enabled = !disabled && onChanged != null;

    // 1. The track keeps the whole semantics node; the visible label below is
    //    excluded so a screen reader hears the name once, not twice.
    final Widget track = WSwitch(
      value: value,
      onChanged: onChanged,
      disabled: disabled,
      className: _resolveClassName(),
      thumbClassName: _resolveThumbClassName(),
      semanticLabel: semanticLabel ?? label,
    );

    // 2. The area around the track is the tap target. The track's own anchor
    //    still wins a tap that lands on it, so a toggle never fires twice, and
    //    MergeSemantics hands assistive technology one node the size of the
    //    area rather than a 24 px one inside it.
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: label == null
            ? WDiv(className: switchHitAreaRecipe(), child: track)
            : WDiv(
                className: switchLabelledHitAreaRecipe(),
                child: _SwitchLabelLayout(
                  track: track,
                  label: ExcludeSemantics(
                    child: WText(
                      label!,
                      className: enabled
                          ? switchLabelClassName
                          : '$switchLabelClassName opacity-50',
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

enum _SwitchSlot { track, label }

/// Lays the track and its label out on one centre line.
///
/// Not a flex row: a label with a flex share throws in a row of unbounded
/// width (the trailing slot of a settings row), and a [LayoutBuilder] choosing
/// between the two throws under [IntrinsicHeight]. Here the label wraps in
/// whatever width is left beside the track when the width is bounded, keeps
/// its natural width when it is not, and both answer intrinsic queries.
class _SwitchLabelLayout
    extends SlottedMultiChildRenderObjectWidget<_SwitchSlot, RenderBox> {
  const _SwitchLabelLayout({required this.track, required this.label});

  final Widget track;
  final Widget label;

  @override
  Iterable<_SwitchSlot> get slots => _SwitchSlot.values;

  @override
  Widget? childForSlot(_SwitchSlot slot) => switch (slot) {
    _SwitchSlot.track => track,
    _SwitchSlot.label => label,
  };

  @override
  _RenderSwitchLabelLayout createRenderObject(BuildContext context) =>
      _RenderSwitchLabelLayout(Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSwitchLabelLayout renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _RenderSwitchLabelLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<_SwitchSlot, RenderBox> {
  _RenderSwitchLabelLayout(this._textDirection);

  /// Wind's `gap-3`.
  static const double _gap = 12;

  TextDirection _textDirection;

  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _track => childForSlot(_SwitchSlot.track)!;
  RenderBox get _label => childForSlot(_SwitchSlot.label)!;

  double _labelMaxWidth(double width, double trackWidth) =>
      width.isFinite ? math.max(0, width - trackWidth - _gap) : double.infinity;

  Size _sizeFor(BoxConstraints constraints, Size track, Size label) =>
      constraints.constrain(
        Size(
          track.width + _gap + label.width,
          math.max(track.height, label.height),
        ),
      );

  @override
  double computeMinIntrinsicWidth(double height) =>
      _track.getMinIntrinsicWidth(height) +
      _gap +
      _label.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _track.getMaxIntrinsicWidth(height) +
      _gap +
      _label.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) {
    final double trackWidth = _track.getMaxIntrinsicWidth(double.infinity);
    return math.max(
      _track.getMinIntrinsicHeight(trackWidth),
      _label.getMinIntrinsicHeight(_labelMaxWidth(width, trackWidth)),
    );
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final double trackWidth = _track.getMaxIntrinsicWidth(double.infinity);
    return math.max(
      _track.getMaxIntrinsicHeight(trackWidth),
      _label.getMaxIntrinsicHeight(_labelMaxWidth(width, trackWidth)),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final Size track = _track.getDryLayout(const BoxConstraints());
    final Size label = _label.getDryLayout(
      BoxConstraints(
        maxWidth: _labelMaxWidth(constraints.maxWidth, track.width),
      ),
    );
    return _sizeFor(constraints, track, label);
  }

  @override
  void performLayout() {
    _track.layout(const BoxConstraints(), parentUsesSize: true);
    _label.layout(
      BoxConstraints(
        maxWidth: _labelMaxWidth(constraints.maxWidth, _track.size.width),
      ),
      parentUsesSize: true,
    );
    size = _sizeFor(constraints, _track.size, _label.size);

    final bool ltr = _textDirection == TextDirection.ltr;
    final double trackX = ltr ? 0 : size.width - _track.size.width;
    final double labelX = ltr
        ? _track.size.width + _gap
        : size.width - _track.size.width - _gap - _label.size.width;
    (_track.parentData! as BoxParentData).offset = Offset(
      trackX,
      (size.height - _track.size.height) / 2,
    );
    (_label.parentData! as BoxParentData).offset = Offset(
      labelX,
      (size.height - _label.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final RenderBox child in children) {
      context.paintChild(
        child,
        (child.parentData! as BoxParentData).offset + offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final RenderBox child in children) {
      final BoxParentData parentData = child.parentData! as BoxParentData;
      final bool hit = result.addWithPaintOffset(
        offset: parentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
