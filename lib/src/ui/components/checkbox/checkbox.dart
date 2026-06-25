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
/// Checkbox(
///   value: _accepted,
///   onChanged: (v) => setState(() => _accepted = v),
/// )
/// ```
@immutable
class Checkbox extends StatelessWidget {
  /// Whether the checkbox is checked.
  final bool value;

  /// Called when the checkbox value changes.
  final ValueChanged<bool>? onChanged;

  /// Whether the checkbox is disabled.
  final bool disabled;

  /// Optional className override that bypasses the recipe entirely.
  final String? className;

  /// Creates a [Checkbox].
  const Checkbox({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
    this.className,
  });

  /// Resolves the className from the recipe or the caller override.
  String _resolveClassName() {
    if (className != null) {
      return className!;
    }

    return checkboxRecipe();
  }

  @override
  Widget build(BuildContext context) {
    return WCheckbox(
      value: value,
      onChanged: onChanged,
      disabled: disabled,
      className: _resolveClassName(),
    );
  }
}
