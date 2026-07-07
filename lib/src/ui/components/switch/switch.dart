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

  /// Creates a [MSSwitch].
  const MSSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.disabled = false,
    this.className,
    this.thumbClassName,
    this.semanticLabel,
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
    return WSwitch(
      value: value,
      onChanged: onChanged,
      disabled: disabled,
      className: _resolveClassName(),
      thumbClassName: _resolveThumbClassName(),
      semanticLabel: semanticLabel,
    );
  }
}
