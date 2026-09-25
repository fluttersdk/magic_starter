import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../button/button.dart';
import '../button/button.recipe.dart';
import 'form_actions.recipe.dart';

/// The action row that closes a form: an optional cancel and the primary
/// submit, right-aligned at the bottom of the fields.
///
/// One definition, so a form's submit sits in the same place on every screen
/// that uses it, rather than each caller re-deriving the footer layout.
///
/// The submit is auto-width and never full-width. A Wind full-width button
/// hands its row an unbounded child and aborts the layout, so the row flows
/// (`wrap`) rather than stretching its children.
///
/// ### Example
/// ```dart
/// MSFormActions(
///   submitLabel: 'Save',
///   isSubmitting: isSubmitting,
///   onSubmit: () => submitOnce(_save),
/// )
/// ```
@immutable
class MSFormActions extends StatelessWidget {
  /// Label of the primary submit button.
  final String submitLabel;

  /// Invoked on submit. Null renders the button disabled.
  final VoidCallback? onSubmit;

  /// Whether a submit is in flight.
  ///
  /// Passed to [MSButton.isLoading], which is the GUARD and not only the
  /// spinner: the button drops its tap while loading, so a double tap cannot
  /// create two of anything.
  final bool isSubmitting;

  /// Label of the optional cancel button. Null renders no cancel button.
  final String? cancelLabel;

  /// Invoked on cancel. Ignored when [cancelLabel] is null.
  final VoidCallback? onCancel;

  /// Optional className appended after the recipe output.
  final String? className;

  /// Creates a [MSFormActions] row.
  const MSFormActions({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.isSubmitting = false,
    this.cancelLabel,
    this.onCancel,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: formActionsRecipe()(className: className),
      children: <Widget>[
        if (cancelLabel != null)
          MSButton(
            intent: ButtonIntent.secondary,
            onPressed: isSubmitting ? null : onCancel,
            child: WText(cancelLabel!),
          ),
        MSButton(
          // Named explicitly, because the label does not survive the loading
          // state: Wind's `WButton` REPLACES its child with the spinner, so
          // there is no text left for `MergeSemantics` to absorb and the
          // submit control reaches a screen reader as an unnamed button for
          // exactly as long as the request is in flight.
          semanticLabel: submitLabel,
          isLoading: isSubmitting,
          onPressed: onSubmit,
          child: WText(submitLabel),
        ),
      ],
    );
  }
}
