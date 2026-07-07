import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'skeleton.recipe.dart';

/// Shape variants for [MSSkeleton].
///
/// - [block] — Rectangular block placeholder (e.g. image, card).
/// - [text] — Short inline text-line placeholder.
/// - [circle] — Circular avatar or icon placeholder.
enum SkeletonShape {
  /// Rectangular block: `rounded-md`.
  block,

  /// Inline text line: `rounded`.
  text,

  /// Circle avatar / icon: `rounded-full`.
  circle,
}

/// A loading placeholder built on [WDiv].
///
/// Renders a pulsing muted block using the semantic token
/// `bg-surface-container-high` (the nearest semantic equivalent to
/// `bg-muted` — there is no dedicated `bg-muted` alias in
/// [MagicStarterTokens.defaultAliases]). The `animate-pulse` className drives
/// the shimmer animation via wind's animation parser.
///
/// Callers supply [width] and [height] to size the placeholder; [shape]
/// controls the border-radius via the recipe.
///
/// ```dart
/// MSSkeleton(width: 200, height: 80)                        // block (default)
/// MSSkeleton(shape: SkeletonShape.circle, width: 48, height: 48)
/// MSSkeleton(shape: SkeletonShape.text, width: 160, height: 16)
/// ```
@immutable
class MSSkeleton extends StatelessWidget {
  /// The visual shape controlling border-radius.
  ///
  /// Defaults to [SkeletonShape.block].
  final SkeletonShape shape;

  /// The width of the skeleton placeholder in logical pixels.
  ///
  /// When `null` the placeholder fills its parent's width.
  final double? width;

  /// The height of the skeleton placeholder in logical pixels.
  final double? height;

  /// Optional caller className appended after the recipe output.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens override the
  /// matching recipe classes while every non-overridden base class survives.
  final String? className;

  /// Creates a [MSSkeleton] widget.
  const MSSkeleton({
    super.key,
    this.shape = SkeletonShape.block,
    this.width,
    this.height,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: WDiv(
        className: skeletonRecipe(
          variants: {kSkeletonShapeAxis: shape.name},
          className: className,
        ),
      ),
    );
  }
}
