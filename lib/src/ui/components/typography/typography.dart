import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'typography.recipe.dart';

/// Visual variants for [Typography].
///
/// - [h1] — Display heading: largest size, bold weight.
/// - [h2] — Section heading: large size, bold weight.
/// - [h3] — Sub-section heading: medium size, semibold weight.
/// - [body] — Default body text: base size, normal weight, relaxed leading.
/// - [caption] — Supporting caption text: smaller size, muted foreground.
enum TypographyVariant {
  /// Display heading: `text-4xl font-bold`.
  h1,

  /// Section heading: `text-3xl font-bold`.
  h2,

  /// Sub-section heading: `text-2xl font-semibold`.
  h3,

  /// Body text: `text-base font-normal`.
  body,

  /// Caption / label text: `text-sm text-fg-muted`.
  caption,
}

/// A polymorphic text component built on [WText].
///
/// Resolves its className through a [WindRecipe] (`typography.recipe.dart`)
/// so every variant reads from the semantic token alias map. No raw hex or
/// `Colors.*` anywhere.
///
/// ```dart
/// Typography('Page Title', variant: TypographyVariant.h1)
/// Typography('Some paragraph text.')  // defaults to body
/// Typography('Created at 09:00', variant: TypographyVariant.caption)
/// ```
@immutable
class Typography extends StatelessWidget {
  /// The text content to display.
  final String data;

  /// The typographic scale variant controlling size, weight, and leading.
  ///
  /// Defaults to [TypographyVariant.body].
  final TypographyVariant variant;

  /// Optional caller className appended after the recipe output.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens override the
  /// matching recipe classes while every non-overridden base class survives.
  final String? className;

  /// Creates a [Typography] widget.
  const Typography(
    this.data, {
    super.key,
    this.variant = TypographyVariant.body,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    return WText(
      data,
      className: typographyRecipe(
        variants: {kTypographyVariantAxis: variant.name},
        className: className,
      ),
    );
  }
}
