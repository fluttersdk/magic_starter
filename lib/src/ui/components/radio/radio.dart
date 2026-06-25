import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'radio.recipe.dart';

/// A reusable radio button component for Magic Starter forms.
///
/// Wraps [WRadio] with [WindRecipe] tokens that explicitly override wind's
/// built-in defaults (`border-gray-300`, `bg-blue-500`) so the radio shell and
/// indicator use semantic aliases instead of hardcoded palette colors.
///
/// ### Usage
///
/// ```dart
/// // Inside a group: every radio shares the same groupValue.
/// Radio<String>(
///   value: 'email',
///   groupValue: _channel,
///   onChanged: (v) => setState(() => _channel = v),
/// )
/// ```
@immutable
class Radio<T> extends StatelessWidget {
  /// The value this radio button represents.
  final T value;

  /// The currently selected value in the group.
  final T? groupValue;

  /// Called with [value] when this radio is tapped while not selected.
  final ValueChanged<T>? onChanged;

  /// Whether the radio is disabled.
  final bool disabled;

  /// Optional className override for the shell, bypassing the recipe.
  final String? className;

  /// Optional className override for the indicator dot, bypassing the recipe.
  final String? indicatorClassName;

  /// Accessible label for the radio (required for unlabelled usage).
  final String? semanticLabel;

  /// Creates a [Radio].
  const Radio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.disabled = false,
    this.className,
    this.indicatorClassName,
    this.semanticLabel,
  });

  /// Resolves the shell className from the recipe or the caller override.
  String _resolveClassName() => className ?? radioShellRecipe();

  /// Resolves the indicator className from the recipe or the caller override.
  String _resolveIndicatorClassName() =>
      indicatorClassName ?? radioIndicatorRecipe();

  @override
  Widget build(BuildContext context) {
    return WRadio<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      disabled: disabled,
      className: _resolveClassName(),
      indicatorClassName: _resolveIndicatorClassName(),
      semanticLabel: semanticLabel,
    );
  }
}
