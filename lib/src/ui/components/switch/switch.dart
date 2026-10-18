import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

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

    // 2. The row around the track is the tap target. The track's own anchor
    //    still wins a tap that lands on it, so a toggle never fires twice, and
    //    MergeSemantics hands assistive technology one node the size of the
    //    row rather than a 24 px one inside it.
    Widget hitArea(bool wrapsLabel) => WDiv(
      className: switchHitAreaRecipe(),
      children: [
        track,
        if (label != null)
          WDiv(
            className: wrapsLabel ? switchLabelCellClassName : null,
            child: ExcludeSemantics(
              child: WText(
                label!,
                className: enabled
                    ? switchLabelClassName
                    : '$switchLabelClassName opacity-50',
              ),
            ),
          ),
      ],
    );

    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: enabled ? () => onChanged!(!value) : null,
        // 3. The label's flex share only exists inside a bounded width. A
        //    trailing slot of a settings row measures its child unbounded, and
        //    a flex child there throws, so the label keeps its natural width.
        child: label == null
            ? hitArea(false)
            : LayoutBuilder(
                builder: (context, constraints) =>
                    hitArea(constraints.hasBoundedWidth),
              ),
      ),
    );
  }
}
