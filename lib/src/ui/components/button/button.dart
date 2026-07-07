import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'button.recipe.dart';

/// A reusable button component for Magic Starter views.
///
/// Composes [WButton] with a [WindRecipe] to provide consistent styling across
/// all intents and sizes. Semantic tokens (Step 7) drive colors so a
/// `DESIGN.md` override re-skins every button without touching this file.
///
/// ### Variant styles
///
/// ```dart
/// Button(
///   intent: ButtonIntent.destructive,
///   size: ButtonSize.lg,
///   onPressed: _deleteAccount,
///   child: const WText('Delete account'),
/// )
/// ```
///
/// ### Loading state
///
/// ```dart
/// Button(
///   onPressed: _submit,
///   isLoading: controller.isLoading,
///   child: const WText('Submit'),
/// )
/// ```
@immutable
class Button extends StatelessWidget {
  /// The button content.
  final Widget child;

  /// Called when the button is tapped and not loading/disabled.
  final VoidCallback? onPressed;

  /// Visual intent of the button.
  final ButtonIntent intent;

  /// Size of the button.
  final ButtonSize size;

  /// Whether the button shows a loading spinner.
  final bool isLoading;

  /// Whether the button is disabled.
  final bool disabled;

  /// Whether the button fills the width of its parent.
  ///
  /// Material widgets ignore cross-axis stretch inside a `Column`
  /// (flutter/flutter#19399), so this is not a recipe/className concern:
  /// it wraps the rendered [WButton] in a `SizedBox(width: double.infinity)`
  /// at the widget layer. Orthogonal to [size] (a layout concern, not the
  /// padding/font scale). Defaults to `false` (content-width).
  final bool fullWidth;

  /// Optional caller className appended after the recipe output.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens override the
  /// matching recipe classes while every non-overridden base class survives.
  final String? className;

  /// An explicit accessible label for icon-only buttons.
  final String? semanticLabel;

  /// Creates a [Button].
  const Button({
    super.key,
    required this.child,
    this.onPressed,
    this.intent = ButtonIntent.primary,
    this.size = ButtonSize.md,
    this.isLoading = false,
    this.disabled = false,
    this.fullWidth = false,
    this.className,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final Widget button = WButton(
      onTap: onPressed,
      isLoading: isLoading,
      disabled: disabled,
      className: buttonRecipe(
        variants: {
          kButtonIntentAxis: intent.name,
          kButtonSizeAxis: size.name,
        },
        className: className,
      ),
      semanticLabel: semanticLabel,
      child: child,
    );

    if (!fullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}
