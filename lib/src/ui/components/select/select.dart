import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'select.recipe.dart';

/// A styled single-select dropdown component for Magic Starter.
///
/// Wraps [WSelect] with semantic-token classNames resolved from [selectRecipe].
/// The caller supplies [options], a controlled [value], and an [onChange]
/// callback; all visual tokens come from the slot recipe.
///
/// ### Example Usage:
///
/// ```dart
/// MSSelect<String>(
///   value: _selected,
///   options: countries,
///   onChange: (v) => setState(() => _selected = v),
/// )
/// ```
///
/// ### Slot override:
///
/// Pass [classNames] to override individual slot classNames (the override is
/// appended last, per the WindSlotRecipe caller-append contract):
///
/// ```dart
/// MSSelect<String>(
///   value: _selected,
///   options: options,
///   onChange: (_) {},
///   classNames: {'trigger': 'border-red-500'},
/// )
/// ```
@immutable
class MSSelect<T> extends StatelessWidget {
  /// Currently selected value, or `null` when nothing is selected.
  final T? value;

  /// The list of available options.
  final List<SelectOption<T>> options;

  /// Called when the user selects an option.
  final ValueChanged<T?>? onChange;

  /// Optional placeholder shown when [value] is `null`.
  final String? placeholder;

  /// Whether the dropdown is disabled.
  final bool disabled;

  /// Per-slot className overrides appended after the recipe output.
  final Map<String, String>? classNames;

  /// Creates a [MSSelect] widget.
  const MSSelect({
    super.key,
    required this.options,
    this.value,
    this.onChange,
    this.placeholder,
    this.disabled = false,
    this.classNames,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Resolve slot classNames from the recipe.
    final slots = selectRecipe(classNames: classNames);

    // 2. Delegate to WSelect with recipe-driven classNames.
    return WSelect<T>(
      value: value,
      options: options,
      onChange: onChange,
      placeholder: placeholder ?? 'Select an option',
      disabled: disabled,
      className: slots['trigger'],
      menuClassName: slots['popup'],
    );
  }
}
