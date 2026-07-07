import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'checkbox.recipe.dart';

/// A reusable checkbox component for Magic Starter forms.
///
/// Wraps [WCheckbox] with a [WindRecipe] that applies semantic tokens so the
/// box background and border follow the brand without hardcoded colors.
///
/// ### Usage
///
/// ```dart
/// MSCheckbox(
///   value: _accepted,
///   onChanged: (v) => setState(() => _accepted = v),
/// )
/// ```
@immutable
class MSCheckbox extends StatelessWidget {
  /// Whether the checkbox is checked.
  final bool value;

  /// Called when the checkbox value changes.
  final ValueChanged<bool>? onChanged;

  /// Whether the checkbox is disabled.
  final bool disabled;

  /// Optional caller className appended after the recipe output.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens override the
  /// matching recipe classes while every non-overridden base class survives.
  final String? className;

  /// Creates a [MSCheckbox].
  const MSCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    return WCheckbox(
      value: value,
      onChanged: onChanged,
      disabled: disabled,
      className: checkboxRecipe(className: className),
    );
  }
}
