import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../theme/magic_starter_tokens.dart';
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
/// Renders a styled banner using semantic tokens via [buildToastRecipe]. This
/// widget is the presentational layer: it can be composed inline in previews or
/// shown from a host's own overlay. It does not present itself, time itself out
/// or dismiss itself: the host that shows it decides how long it stays, and
/// whether pressing the action closes it.
///
/// The magic framework's `Magic.toast(String)` is not a way to show an action.
/// It takes only a message, and the overlay it presents is an `IgnorePointer`,
/// so nothing in it can be pressed. A host that wants an action presents the
/// `MSToast` itself, through its own `OverlayEntry`.
///
/// ### Example
/// ```dart
/// MSToast(
///   message: 'Profile updated successfully',
///   variant: ToastVariant.success,
/// )
/// ```
///
/// ### Colours
///
/// `info` is `text-fg` on `bg-surface`. The three toned variants read the
/// on-colour role of their fill for the message, the action label and the focus
/// ring: `text-on-success`, `text-on-warning` and `text-on-destructive`. A host
/// whose dark fills are light defines them dark there, so the text keeps 4.5:1
/// on the fill; without a role the toast falls back to near-black on the success
/// and warning fills (it reads on the stock green and amber) and to the alias
/// map's white on the destructive one.
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
/// the info surface, the on-colour role of the fill on the three coloured
/// ones), in a cell at least 44 px each way at every width (it grows with the
/// label at a large text size), so it is a hit target on a phone and under a
/// pointer alike. The cell is named for assistive technology by [actionLabel],
/// takes keyboard focus (Tab) and shows a ring inside the toast when it has it,
/// and Enter or Space presses it. A one line toast is as tall with an action as
/// without. A long message wraps in the width beside the action; the action
/// keeps its size. The padding is logical, so a right to left toast keeps the
/// same distances from its edges.
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
    final WindThemeData? windTheme = WindTheme.maybeDataOf(context);

    // 1. Without an action the toast is the banner it always was.
    if (label == null || onPressed == null) {
      return WDiv(
        className: buildToastRecipe(windTheme)(
          variants: {kToastVariantAxis: variant.name},
          className: className,
        ),
        child: WText(message, className: 'text-sm font-medium'),
      );
    }

    // 2. A toned toast hands its action the on-colour role of the fill, and the
    //    colour that role paints now, for the ring and the hover fill.
    final String? baseRole = toastOnRole(variant.name);
    final String? onRole = baseRole == null
        ? null
        : MagicStarterTokens.role(windTheme, baseRole);
    final Color? onColour = onRole == null
        ? null
        : WindParser.parse(onRole, context).color;
    final Map<String, String> action = toastActionRecipe(
      onRole: onRole,
      onColour: onColour,
    );

    // 3. The message column takes the vertical padding and the 44 px cell sits
    //    at the trailing edge; the caller's className still comes last.
    return WDiv(
      className: buildToastRecipe(windTheme)(
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
            // The label's size raised to the cell's minimum, so it is centred
            // in 44 px and never taller than that asks for.
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: WText(label, className: action['label']),
            ),
          ),
        ),
      ],
    );
  }
}
