import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../button/button.dart';
import '../button/button.recipe.dart';
import 'header_action.recipe.dart';

/// A page-header action that becomes an icon-only control on a phone.
///
/// A labelled button is the right control for a header on a desktop and the
/// wrong one on a phone: a full-width label costs the header a row of its
/// own below the title, which is where the conventional control is a single
/// glyph beside it. Below `lg` this renders that glyph, at `lg` and up the
/// labelled [MSButton] it always was.
///
/// The [label] is never dropped, only moved: on the icon form it becomes the
/// accessibility label, because an icon-only control otherwise reaches a
/// screen reader as an unnamed button.
///
/// ### Example
/// ```dart
/// MSHeaderAction(
///   icon: Icons.add,
///   label: 'New monitor',
///   onPressed: () => MagicRoute.to('/monitors/new'),
/// )
/// ```
@immutable
class MSHeaderAction extends StatelessWidget {
  /// The glyph shown instead of [label] below `lg`.
  final IconData icon;

  /// The action's name: the button text at `lg` and up, the accessibility
  /// label below it.
  final String label;

  /// Invoked on tap. A null callback renders both forms disabled.
  final VoidCallback? onPressed;

  /// Which button the labelled form renders, and how prominent the glyph is.
  final ButtonIntent intent;

  /// Optional className appended after the recipe output on the icon form.
  final String? className;

  /// Creates a [MSHeaderAction].
  const MSHeaderAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.intent = ButtonIntent.primary,
    this.className,
  });

  /// The recipe's `intent` value, folding a null callback into `disabled`.
  String get _glyphIntent {
    if (onPressed == null) return 'disabled';

    return intent == ButtonIntent.primary ? 'primary' : 'secondary';
  }

  @override
  Widget build(BuildContext context) {
    // `wScreenIs` reads the same MediaQuery width a caller's own `lg:` tokens
    // resolve against, so the control and the row it sits in switch together.
    if (wScreenIs(context, 'lg')) {
      return MSButton(
        intent: intent,
        onPressed: onPressed,
        child: WText(label),
      );
    }

    // MergeSemantics, not a bare Semantics wrapper: the tap action lives on
    // the gesture detector INSIDE, so without the merge a screen reader sees
    // two nodes, one carrying the name and no action and one carrying the
    // action and no name.
    final Widget glyph = WDiv(
      className: headerActionRecipe()(
        variants: {'intent': _glyphIntent},
        className: className,
      ),
      child: WIcon(icon, className: 'text-[22px]'),
    );

    // A disabled action drops the anchor entirely rather than handing it a
    // null callback: WAnchor keeps advertising a tap action either way, so
    // the glyph would announce itself as tappable while doing nothing.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        child: onPressed == null
            ? glyph
            : WAnchor(onTap: onPressed, child: glyph),
      ),
    );
  }
}
