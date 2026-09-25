import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey, TextInputAction;
import 'package:magic/magic.dart';

import '../button/button.dart';
import '../button/button.recipe.dart';
import '../input/input.dart';
import 'string_value_list.recipe.dart';

/// The visual tone of a [MSStringValueList]'s chips; maps to the `tone` axis
/// of [stringValueListRecipe].
enum StringValueListTone {
  /// Unremarkable: `bg-surface-container-high`.
  neutral,

  /// Cautionary: the warning token pair.
  warn,

  /// Severe: the tinted destructive-container token pair.
  critical,
}

/// **Controlled editor for a short list of distinct strings.**
///
/// Each committed value renders as a [WBadge] chip; pressing Enter (web) or
/// the IME "done" action (mobile) commits the typed draft via
/// [MSInput.onSubmitted]. Every mutation calls [onChanged] with a FRESH list,
/// never mutating [value] in place, so the parent stays the single source of
/// truth.
///
/// A value is trimmed before it is compared or committed; an empty or
/// duplicate (case-insensitive, post-trim) value is rejected silently rather
/// than surfacing an inline error for a no-op edit. The duplicate check folds
/// case and trims BOTH sides so a value already carrying incidental
/// whitespace still blocks a visually identical chip from joining it.
///
/// Backspace-to-remove-the-last-chip is implemented here (wind ships no
/// keyboard handling of its own): a [Focus] wraps the entry field and drops
/// the last committed chip when Backspace is pressed on an already empty
/// draft, mirroring the affordance most chip-input widgets provide.
///
/// Every visible string is a required constructor parameter: the component
/// reads no translation key of its own, so it composes into a consuming
/// app's own catalogue instead of assuming one.
///
/// ### Example:
/// ```dart
/// MSStringValueList(
///   value: warnValues,
///   onChanged: (next) => setState(() => warnValues = next),
///   tone: StringValueListTone.warn,
///   placeholder: 'Enter value',
///   addLabel: 'Add value',
///   removeValueLabel: (value) => 'Remove $value',
/// )
/// ```
@immutable
class MSStringValueList extends StatefulWidget {
  /// Controlled list of committed values, in insertion order.
  final List<String> value;

  /// Called with a fresh copy whenever a value is added or removed.
  final ValueChanged<List<String>> onChanged;

  /// Chip tone; selects which token family the chips render with.
  ///
  /// Defaults to [StringValueListTone.neutral].
  final StringValueListTone tone;

  /// Placeholder for the entry field.
  final String placeholder;

  /// Label of the commit button.
  final String addLabel;

  /// Builds the accessible label for a chip's remove control from its value.
  final String Function(String value) removeValueLabel;

  /// Optional extra classNames appended to the root slot.
  final String? className;

  /// Creates a [MSStringValueList].
  const MSStringValueList({
    super.key,
    required this.value,
    required this.onChanged,
    this.tone = StringValueListTone.neutral,
    required this.placeholder,
    required this.addLabel,
    required this.removeValueLabel,
    this.className,
  });

  @override
  State<MSStringValueList> createState() => _MSStringValueListState();
}

class _MSStringValueListState extends State<MSStringValueList> {
  static const IconData _removeIcon = Icons.close;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Trims [raw], and either appends it as a new value (emitting a fresh
  /// list) or drops it silently when it is empty or already present
  /// (post-trim, case-insensitive). Clears the draft either way, then
  /// refocuses the entry field so the caller can keep typing without an
  /// extra tap.
  void _commit(String raw) {
    final trimmed = raw.trim();
    _controller.clear();

    final folded = trimmed.toLowerCase();
    final isDuplicate =
        trimmed.isNotEmpty &&
        widget.value.any((existing) => existing.trim().toLowerCase() == folded);
    if (trimmed.isNotEmpty && !isDuplicate) {
      widget.onChanged([...widget.value, trimmed]);
    }

    _focusNode.requestFocus();
  }

  /// Removes the value at [index], emitting a fresh list.
  void _removeAt(int index) {
    widget.onChanged([
      for (var i = 0; i < widget.value.length; i++)
        if (i != index) widget.value[i],
    ]);
  }

  /// Drops the last committed value when Backspace is pressed on an empty
  /// draft. `wind` has no keyboard handling of its own, so this is a plain
  /// Flutter [KeyEvent] check around the entry field's [FocusNode].
  void _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return;
    if (_controller.text.isNotEmpty || widget.value.isEmpty) return;

    _removeAt(widget.value.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final slots = stringValueListRecipe(
      variants: {kStringValueListToneAxis: widget.tone.name},
    );

    return WDiv(
      className: widget.className == null
          ? slots['root']
          : '${slots['root']} ${widget.className}',
      children: [
        if (widget.value.isNotEmpty)
          WDiv(
            className: slots['chips'],
            children: [
              for (var i = 0; i < widget.value.length; i++) _chip(i, slots),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  _onKeyEvent(node, event);
                  return KeyEventResult.ignored;
                },
                child: MSInput(
                  controller: _controller,
                  focusNode: _focusNode,
                  placeholder: widget.placeholder,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _commit,
                ),
              ),
            ),
            const SizedBox(width: 8),
            MSButton(
              intent: ButtonIntent.secondary,
              size: ButtonSize.sm,
              onPressed: () => _commit(_controller.text),
              child: WText(widget.addLabel),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(int index, Map<String, String> slots) {
    final entry = widget.value[index];
    // `flex flex-row`, never `inline-flex`: wind's display map knows
    // `flex`/`grid`/`wrap`/`block`, so `inline-flex` is an unrecognised
    // token, an unrecognised token is a silent no-op, and the wrapper would
    // lay out with no axis at all, stacking the remove button under its chip.
    return WDiv(
      className: 'flex flex-row items-center gap-1',
      children: [
        WBadge(entry, className: slots['chip']),
        WAnchor(
          // Names the value it removes, not just "remove": several chips sit
          // in one row, and an unnamed icon button in each of them tells a
          // screen reader user nothing about which one they are about to
          // drop.
          semanticLabel: widget.removeValueLabel(entry),
          onTap: () => _removeAt(index),
          child: WDiv(
            className: slots['remove'],
            child: WIcon(_removeIcon, className: 'size-3'),
          ),
        ),
      ],
    );
  }
}
