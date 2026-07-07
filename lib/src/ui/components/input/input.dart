import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'input.recipe.dart';

/// A reusable text input component for Magic Starter forms.
///
/// Wraps [WInput] with a [WindRecipe] that applies semantic tokens for
/// background and border. Use [state] to signal validation errors.
///
/// ### Basic usage
///
/// ```dart
/// MSInput(
///   placeholder: 'Email address',
///   type: InputType.email,
///   onChanged: (v) => controller.email = v,
/// )
/// ```
///
/// ### Error state
///
/// ```dart
/// MSInput(
///   placeholder: 'Email address',
///   state: InputState.error,
///   onChanged: (v) => controller.email = v,
/// )
/// ```
@immutable
class MSInput extends StatelessWidget {
  /// The controlled value of the input.
  final String? value;

  /// Called when the user changes the input value.
  final ValueChanged<String>? onChanged;

  /// The keyboard type and obscure-text behavior.
  final InputType type;

  /// Visual state of the input.
  final InputState state;

  /// Placeholder text shown when the input is empty.
  final String? placeholder;

  /// Whether the input is enabled.
  final bool enabled;

  /// Whether the input is read-only.
  final bool readOnly;

  /// The action button on the keyboard.
  final TextInputAction? textInputAction;

  /// Called when the user submits the input.
  final ValueChanged<String>? onSubmitted;

  /// Called when the input loses focus.
  final VoidCallback? onEditingComplete;

  /// Called when the input is tapped.
  final VoidCallback? onTap;

  /// Called when the user taps outside the input.
  final TapRegionCallback? onTapOutside;

  /// Maximum number of lines.
  final int? maxLines;

  /// Minimum number of lines.
  final int minLines;

  /// External focus node.
  final FocusNode? focusNode;

  /// External text editing controller.
  final TextEditingController? controller;

  /// Input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Whether the input fills the width of its parent.
  ///
  /// Wraps the rendered [WInput] in a `SizedBox(width: double.infinity)` at
  /// the widget layer, matching Flutter's cross-axis-stretch workaround
  /// (flutter/flutter#19399) rather than baking width into the recipe.
  /// Orthogonal to layout state; defaults to `false` (content-width).
  final bool fullWidth;

  /// Optional caller className appended after the recipe output.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens override the
  /// matching recipe classes while every non-overridden base class survives.
  final String? className;

  /// Widget displayed before the input text.
  final Widget? prefix;

  /// Widget displayed after the input text.
  final Widget? suffix;

  /// Accessible label for the input.
  final String? semanticLabel;

  /// Creates an [MSInput].
  const MSInput({
    super.key,
    this.value,
    this.onChanged,
    this.type = InputType.text,
    this.state = InputState.normal,
    this.placeholder,
    this.enabled = true,
    this.readOnly = false,
    this.textInputAction,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.maxLines,
    this.minLines = 1,
    this.focusNode,
    this.controller,
    this.inputFormatters,
    this.fullWidth = false,
    this.className,
    this.prefix,
    this.suffix,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final Widget input = WInput(
      value: value,
      onChanged: onChanged,
      type: type,
      className: inputRecipe(
        variants: {kInputStateAxis: state.name},
        className: className,
      ),
      placeholder: placeholder,
      enabled: enabled,
      readOnly: readOnly,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      onTap: onTap,
      onTapOutside: onTapOutside,
      maxLines: maxLines,
      minLines: minLines,
      focusNode: focusNode,
      controller: controller,
      inputFormatters: inputFormatters,
      prefix: prefix,
      suffix: suffix,
      semanticLabel: semanticLabel,
    );

    if (!fullWidth) {
      return input;
    }

    return SizedBox(width: double.infinity, child: input);
  }
}
