import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'textarea.recipe.dart';

/// A reusable multiline text input component for Magic Starter forms.
///
/// Wraps [WInput] in [InputType.multiline] mode with a [WindRecipe] that
/// applies semantic tokens. Use [state] to signal validation errors.
///
/// ### Basic usage
///
/// ```dart
/// Textarea(
///   placeholder: 'Enter a description',
///   minLines: 3,
///   maxLines: 8,
///   onChanged: (v) => controller.description = v,
/// )
/// ```
@immutable
class Textarea extends StatelessWidget {
  /// The controlled value of the textarea.
  final String? value;

  /// Called when the user changes the textarea value.
  final ValueChanged<String>? onChanged;

  /// Visual state of the textarea.
  final TextareaState state;

  /// Placeholder text shown when the textarea is empty.
  final String? placeholder;

  /// Whether the textarea is enabled.
  final bool enabled;

  /// Whether the textarea is read-only.
  final bool readOnly;

  /// Maximum number of lines before scrolling.
  final int? maxLines;

  /// Minimum number of visible lines.
  final int minLines;

  /// External focus node.
  final FocusNode? focusNode;

  /// External text editing controller.
  final TextEditingController? controller;

  /// Optional className override that bypasses the recipe entirely.
  final String? className;

  /// Accessible label for the textarea.
  final String? semanticLabel;

  /// Creates a [Textarea].
  const Textarea({
    super.key,
    this.value,
    this.onChanged,
    this.state = TextareaState.normal,
    this.placeholder,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines,
    this.minLines = 3,
    this.focusNode,
    this.controller,
    this.className,
    this.semanticLabel,
  });

  /// Resolves the className from the recipe or the caller override.
  String _resolveClassName() {
    if (className != null) {
      return className!;
    }

    return textareaRecipe(
      variants: {kTextareaStateAxis: state.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    return WInput(
      value: value,
      onChanged: onChanged,
      type: InputType.multiline,
      className: _resolveClassName(),
      placeholder: placeholder,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      minLines: minLines,
      focusNode: focusNode,
      controller: controller,
      semanticLabel: semanticLabel,
    );
  }
}
