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
/// MSButton(
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
/// MSButton(
///   onPressed: _submit,
///   isLoading: controller.isLoading,
///   child: const WText('Submit'),
/// )
/// ```
@immutable
class MSButton extends StatelessWidget {
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

  /// Whether the button fills the width of its parent, with its label centred.
  ///
  /// Two things at two layers, and it needs both. Material widgets ignore
  /// cross-axis stretch inside a `Column` (flutter/flutter#19399), so the
  /// stretch is a `SizedBox(width: double.infinity)` around the rendered
  /// [WButton] rather than a recipe class. That widens the box and leaves the
  /// label where it started, so the `justify-center` token goes on the
  /// className as well; [build] carries the reasoning.
  ///
  /// **A stretched button also fills a BOUNDED height.** Wind maps
  /// `justify-center` to `MainAxisAlignment.center`, which `WButton` turns into
  /// its `Container`'s `alignment`
  /// (`wind/lib/src/widgets/w_button.dart:174-178`), and a `Container` with a
  /// non-null alignment expands to its constraints on both axes rather than
  /// one. Under an unbounded height (a `flex flex-col` card, this package's only
  /// full-width site) nothing changes; under a fixed-height footer or a
  /// stretched row the button now fills the height where it used to
  /// shrink-wrap. That is what "full width" usually wants in those parents, and
  /// it is pinned by a test rather than left to be discovered. Orthogonal to
  /// [size] (a layout concern, not the padding/font scale). Defaults to `false`
  /// (content-width).
  final bool fullWidth;

  /// Optional caller className appended after the recipe output.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens override the
  /// matching recipe classes while every non-overridden base class survives.
  final String? className;

  /// An explicit accessible label for icon-only buttons.
  final String? semanticLabel;

  /// Creates a [MSButton].
  const MSButton({
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
        variants: {kButtonIntentAxis: intent.name, kButtonSizeAxis: size.name},
        // `justify-center` ONLY when stretched, which is the one case the
        // recipe's base deliberately cannot cover. Its comment explains why the
        // base omits it: in Wind that token maps to the Container's alignment
        // and forces the button to fill its constraints, which would make every
        // default button full-width. A shrink-wrapped button needs no centering
        // because the padding box already centres its single child.
        //
        // A STRETCHED one does. `SizedBox(width: infinity)` widens the box and
        // leaves the label where it started, so every full-width button in this
        // package rendered its text hard against the left edge: "Upgrade" and
        // "Contact sales" sat in the corner of a centred card while a
        // hand-built marker beside them was centred, and the row read as
        // broken. Here the expansion is exactly what is wanted, so the token
        // composes with the intent instead of fighting it.
        className: fullWidth
            ? 'justify-center ${className ?? ''}'.trim()
            : className,
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
