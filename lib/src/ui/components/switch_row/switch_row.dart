import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../switch/switch.dart';
import 'switch_row.recipe.dart';

/// A labelled toggle that takes its column's full width: an [MSSwitch] with
/// its [MSSwitch.label] beside it.
///
/// The switch lays the label out itself, so the label wraps inside the column
/// instead of overflowing it, toggles the switch when tapped, and is the
/// switch's accessibility name: a screen reader announces the same words the
/// operator reads.
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
  /// cannot reach the label, whose layout belongs to [MSSwitch].
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
      child: MSSwitch(value: value, onChanged: onChanged, label: label),
    );
  }
}
