import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:magic/magic.dart';

import '../button/button.dart';
import '../button/button.recipe.dart';
import '../input/input.dart';
import 'key_value_editor.recipe.dart';

/// A single editable key/value pair in a [MSKeyValueEditor], e.g. one HTTP
/// request header.
@immutable
class MSKeyValueRow {
  /// The key (left input).
  final String key;

  /// The value (right input).
  final String value;

  /// Creates a [MSKeyValueRow].
  const MSKeyValueRow({required this.key, required this.value});

  /// Returns a copy with [key] and/or [value] replaced.
  MSKeyValueRow copyWith({String? key, String? value}) =>
      MSKeyValueRow(key: key ?? this.key, value: value ?? this.value);
}

/// **Controlled editor for an ordered list of key/value pairs.**
///
/// Each row exposes a key input, a value input, and a remove button; a
/// trailing secondary button appends an empty row. Every mutation calls
/// [onChanged] with a FRESH list (never mutating [value] in place), so the
/// parent stays the single source of truth.
///
/// Every visible string is a required constructor parameter: the component
/// reads no translation key of its own, so it composes into a consuming
/// app's own catalogue instead of assuming one.
///
/// ### Example:
/// ```dart
/// MSKeyValueEditor(
///   value: rows,
///   onChanged: (next) => setState(() => rows = next),
///   keyPlaceholder: 'Header',
///   valuePlaceholder: 'Value',
///   addLabel: 'Add header',
///   removeRowLabel: 'Remove row',
/// )
/// ```
@immutable
class MSKeyValueEditor extends StatelessWidget {
  /// Controlled list of rows.
  final List<MSKeyValueRow> value;

  /// Called with a fresh copy whenever a row is edited, added, or removed.
  final ValueChanged<List<MSKeyValueRow>> onChanged;

  /// Placeholder for the key input.
  final String keyPlaceholder;

  /// Placeholder for the value input.
  final String valuePlaceholder;

  /// Label of the trailing append button.
  final String addLabel;

  /// Accessible label applied to every row's remove control.
  final String removeRowLabel;

  /// Optional extra classNames appended to the root slot.
  final String? className;

  /// Creates a [MSKeyValueEditor].
  const MSKeyValueEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.keyPlaceholder,
    required this.valuePlaceholder,
    required this.addLabel,
    required this.removeRowLabel,
    this.className,
  });

  static const IconData _removeIcon = Icons.close;

  void _updateRow(int index, {String? key, String? value}) {
    final next = [
      for (var i = 0; i < this.value.length; i++)
        if (i == index)
          this.value[i].copyWith(key: key, value: value)
        else
          this.value[i],
    ];
    onChanged(next);
  }

  void _removeRow(int index) {
    onChanged([
      for (var i = 0; i < value.length; i++)
        if (i != index) value[i],
    ]);
  }

  void _addRow() {
    onChanged([...value, const MSKeyValueRow(key: '', value: '')]);
  }

  @override
  Widget build(BuildContext context) {
    final slots = keyValueEditorRecipe(variants: const <String, String>{});

    return WDiv(
      className: className == null
          ? slots['root']
          : '${slots['root']} $className',
      children: [
        for (var i = 0; i < value.length; i++) _row(i, slots),
        MSButton(
          intent: ButtonIntent.secondary,
          size: ButtonSize.sm,
          onPressed: _addRow,
          child: WText(addLabel),
        ),
      ],
    );
  }

  Widget _row(int index, Map<String, String> slots) {
    final entry = value[index];
    return Row(
      children: [
        Expanded(
          child: MSInput(
            value: entry.key,
            placeholder: keyPlaceholder,
            onChanged: (v) => _updateRow(index, key: v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MSInput(
            value: entry.value,
            placeholder: valuePlaceholder,
            onChanged: (v) => _updateRow(index, value: v),
          ),
        ),
        const SizedBox(width: 8),
        WAnchor(
          // Icon-only, so there is no child text for the anchor's
          // `MergeSemantics` to absorb: without this the control reaches a
          // screen reader as an unnamed button.
          semanticLabel: removeRowLabel,
          onTap: () => _removeRow(index),
          child: WDiv(
            className: slots['remove'],
            child: WIcon(_removeIcon, className: 'size-4'),
          ),
        ),
      ],
    );
  }
}
