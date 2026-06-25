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
/// Switch(
///   value: _enabled,
///   onChanged: (v) => setState(() => _enabled = v),
/// )
/// ```
@immutable
class Switch extends StatelessWidget {
  /// Whether the switch is on.
  final bool value;

  /// Called when the switch value changes.
  final ValueChanged<bool>? onChanged;

  /// Whether the switch is disabled.
  final bool disabled;

  /// Optional className override for the track, bypassing the recipe.
  final String? className;

  /// Optional className override for the thumb, bypassing the recipe.
  final String? thumbClassName;

  /// Accessible label for the switch (required for icon-only usage).
  final String? semanticLabel;

  /// Creates a [Switch].
  const Switch({
    super.key,
    required this.value,
    required this.onChanged,
    this.disabled = false,
    this.className,
    this.thumbClassName,
    this.semanticLabel,
  });

  /// Resolves the track className from the recipe or the caller override.
  String _resolveClassName() => className ?? switchTrackRecipe();

  /// Resolves the thumb className from the recipe or the caller override.
  String _resolveThumbClassName() => thumbClassName ?? switchThumbRecipe();

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
