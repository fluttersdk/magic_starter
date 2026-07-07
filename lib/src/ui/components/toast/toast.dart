import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'toast.recipe.dart';

/// Visual style variants for [Toast].
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
/// layer that can also be composed inline in previews or custom overlays.
///
/// ### Example
/// ```dart
/// Toast(
///   message: 'Profile updated successfully',
///   variant: ToastVariant.success,
/// )
/// ```
@immutable
class Toast extends StatelessWidget {
  /// The message text to display in the toast.
  final String message;

  /// Visual variant controlling the background/text tone.
  final ToastVariant variant;

  /// Optional caller className appended after the recipe output.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens override the
  /// matching recipe classes while every non-overridden base class survives.
  final String? className;

  /// Creates a [Toast].
  const Toast({
    super.key,
    required this.message,
    this.variant = ToastVariant.info,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Resolve className from the recipe; the caller className appends last.
    final resolvedClassName = buildToastRecipe()(
      variants: {kToastVariantAxis: variant.name},
      className: className,
    );

    // 2. Render the toast banner.
    return WDiv(
      className: resolvedClassName,
      child: WText(message, className: 'text-sm font-medium'),
    );
  }
}
