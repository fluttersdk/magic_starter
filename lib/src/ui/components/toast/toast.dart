import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'toast.recipe.dart';

/// Visual style variants for [MSToast].
///
/// Each variant maps to a semantic token that the design system provides:
/// - [info] — neutral, surface tone.
/// - [success] — green/success tone.
/// - [warning] — amber/warning tone.
/// - [error] — destructive/red tone.
enum ToastVariant {
  /// Neutral informational toast.
  info,

  /// Success/positive feedback toast.
  success,

  /// Cautionary/warning toast.
  warning,

  /// Error/failure toast.
  error,
}

/// A reusable inline toast notification widget.
///
/// Renders a styled banner using semantic tokens via [buildToastRecipe].
/// In-app transient toasts are typically triggered via `Magic.toast()`
/// (the magic framework's overlay API); this widget is the presentational
/// layer that can also be composed inline in previews or custom overlays. It
/// does not present itself, time itself out or dismiss itself: the host that
/// shows it decides how long it stays, and whether pressing the action closes it.
///
/// ### Example
/// ```dart
/// MSToast(
///   message: 'Profile updated successfully',
///   variant: ToastVariant.success,
/// )
/// ```
///
/// ### An action
///
/// [actionLabel] and [onAction] add a text action at the trailing side, for a
/// write the user can take back:
///
/// ```dart
/// MSToast(
///   message: 'Moved to Kitchen',
///   actionLabel: 'Undo',
///   onAction: undoMove,
/// )
/// ```
///
/// The action is a text button in the tone of the variant (a primary label on
/// the info surface, white on the three coloured ones), in a cell at least
/// 44 px each way at every width, so it is a hit target on a phone and under a
/// pointer alike. The cell is named for assistive technology by [actionLabel],
/// takes keyboard focus (Tab) and shows a ring inside the toast when it has it,
/// and Enter or Space presses it. A one line toast is as tall with an action as
/// without. A long message wraps in the width beside the action; the action
/// keeps its size.
@immutable
class MSToast extends StatelessWidget {
  /// The message text to display in the toast.
  final String message;

  /// Visual variant controlling the background/text tone.
  final ToastVariant variant;

  /// Optional caller className appended after the recipe output.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens override the
  /// matching recipe classes while every non-overridden base class survives.
  final String? className;

  /// Label of the trailing text action, already translated. It is also the
  /// action's accessible name.
  ///
  /// Comes with [onAction]: a label without a callback, or the reverse, is an
  /// assertion error. Two plain parameters rather than a value class, as on
  /// [MSUpdateBanner], so the pair adds no type to the package's API.
  final String? actionLabel;

  /// Called when the action is pressed.
  final VoidCallback? onAction;

  /// Creates a [MSToast].
  const MSToast({
    super.key,
    required this.message,
    this.variant = ToastVariant.info,
    this.className,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'MSToast: actionLabel and onAction come together.',
       );

  @override
  Widget build(BuildContext context) {
    final String? label = actionLabel;
    final VoidCallback? onPressed = onAction;

    // 1. Without an action the toast is the banner it always was.
    if (label == null || onPressed == null) {
      return WDiv(
        className: buildToastRecipe()(
          variants: {kToastVariantAxis: variant.name},
          className: className,
        ),
        child: WText(message, className: 'text-sm font-medium'),
      );
    }

    // 2. With one, the message column takes the vertical padding and the 44 px
    //    cell sits at the trailing edge; the caller's className still comes
    //    last.
    final Map<String, String> action = toastActionRecipe(
      variants: {kToastVariantAxis: variant.name},
    );

    return WDiv(
      className: buildToastRecipe()(
        variants: {kToastVariantAxis: variant.name},
        className: <String>[kToastWithActionClassName, ?className].join(' '),
      ),
      children: [
        WDiv(
          className: action['message'],
          child: WText(message, className: 'text-sm font-medium'),
        ),
        WAnchor(
          onTap: onPressed,
          semanticLabel: label,
          child: WDiv(
            className: action['cell'],
            child: WText(label, className: action['label']),
          ),
        ),
      ],
    );
  }
}
