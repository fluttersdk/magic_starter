import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../switch/switch.dart';
import 'switch_row.recipe.dart';

/// A labelled toggle: an [MSSwitch] with its text label beside it.
///
/// One definition, so a caller does not re-derive the label/switch layout
/// (and the `flex-1 min-w-0` shrink fix it depends on) per screen. See
/// [switchRowRecipe] for the layout reasoning.
///
/// The switch renders no label of its own, which is why the label is a
/// sibling here rather than a property of the control. [label] is also the
/// switch's accessibility name, so a screen reader announces the same words
/// the operator reads.
///
/// ### Example
/// ```dart
/// MSSwitchRow(
///   label: 'Repeat the last step until approved',
///   value: _repeatLastStep,
///   onChanged: (bool value) => setState(() => _repeatLastStep = value),
/// )
/// ```
@immutable
class MSSwitchRow extends StatelessWidget {
  /// The text beside the toggle, and the toggle's accessibility name.
  final String label;

  /// Whether the toggle reads on.
  final bool value;

  /// Invoked with the new value when the operator flips the toggle.
  final ValueChanged<bool> onChanged;

  /// Appended to the row's own className, for per-caller spacing only.
  ///
  /// Emission order is recipe then caller, so this can override the row. It
  /// cannot reach the label, which is deliberate: the label's `flex-1
  /// min-w-0` is the fix, and a caller that could replace it would
  /// reintroduce the overflow one screen at a time.
  final String? className;

  /// Creates a [MSSwitchRow].
  const MSSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: switchRowRecipe()(className: className),
      children: <Widget>[
        MSSwitch(value: value, onChanged: onChanged, semanticLabel: label),
        WText(label, className: switchRowLabelClassName),
      ],
    );
  }
}
