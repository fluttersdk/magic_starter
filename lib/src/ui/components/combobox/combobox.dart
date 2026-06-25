import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'combobox.recipe.dart';

/// A searchable single-select combobox component for Magic Starter.
///
/// Extends [Select]'s recipe-driven approach with `searchable: true` wired into
/// the underlying [WSelect], so the user can type to filter options. Supports
/// async [onSearch] for remote filtering.
///
/// ### Example Usage:
///
/// ```dart
/// Combobox<String>(
///   value: _selected,
///   options: countries,
///   onChange: (v) => setState(() => _selected = v),
/// )
/// ```
///
/// ### Async search:
///
/// ```dart
/// Combobox<String>(
///   value: _selected,
///   options: _options,
///   onChange: (v) => setState(() => _selected = v),
///   onSearch: (query) => _fetchOptions(query),
/// )
/// ```
@immutable
class Combobox<T> extends StatelessWidget {
  /// Currently selected value, or `null` when nothing is selected.
  final T? value;

  /// The list of available options (initial set; [onSearch] may update it).
  final List<SelectOption<T>> options;

  /// Called when the user selects an option.
  final ValueChanged<T?>? onChange;

  /// Optional async callback for remote option filtering.
  final Future<List<SelectOption<T>>> Function(String query)? onSearch;

  /// Optional placeholder text shown when [value] is `null`.
  final String? placeholder;

  /// Optional search field placeholder.
  final String? searchPlaceholder;

  /// Whether the combobox is disabled.
  final bool disabled;

  /// Per-slot className overrides appended after the recipe output.
  final Map<String, String>? classNames;

  /// Creates a [Combobox] widget.
  const Combobox({
    super.key,
    required this.options,
    this.value,
    this.onChange,
    this.onSearch,
    this.placeholder,
    this.searchPlaceholder,
    this.disabled = false,
    this.classNames,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Resolve slot classNames from the recipe.
    final slots = comboboxRecipe(classNames: classNames);

    // 2. Delegate to WSelect with searchable:true and recipe-driven classNames.
    return WSelect<T>(
      value: value,
      options: options,
      onChange: onChange,
      placeholder: placeholder ?? 'Search options...',
      searchable: true,
      searchPlaceholder: searchPlaceholder ?? 'Search...',
      onSearch: onSearch,
      disabled: disabled,
      className: slots['trigger'],
      menuClassName: slots['popup'],
    );
  }
}
