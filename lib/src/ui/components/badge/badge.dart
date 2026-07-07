import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'badge.recipe.dart';

/// Visual tone variants for [Badge].
///
/// Each tone maps to a semantic token pair (background + foreground) defined
/// in [MagicStarterTokens.defaultAliases] so the badge re-skins automatically
/// when the consumer supplies a custom alias map.
///
/// - [neutral] — Muted surface fill; low-emphasis label.
/// - [primary] — Brand-colored fill; high-emphasis status.
/// - [accent] — Accent-colored fill; secondary emphasis.
/// - [success] — Green fill; positive / confirmed state.
/// - [warning] — Amber fill; caution / pending state.
/// - [destructive] — Red fill; error / blocked state.
/// - [outline] — Transparent with a visible border; low-prominence label.
enum BadgeTone {
  /// Muted surface: low-emphasis label.
  neutral,

  /// Brand-primary fill: high-emphasis status.
  primary,

  /// Accent fill: secondary emphasis.
  accent,

  /// Green fill: positive / confirmed state.
  success,

  /// Amber fill: caution / pending state.
  warning,

  /// Red fill: error / blocked state.
  destructive,

  /// Transparent background with border: low-prominence label.
  outline,
}

/// A small inline status label built on [WBadge].
///
/// Uses a [WindRecipe] (`badge.recipe.dart`) to emit semantic token class
/// names for each [tone]; no raw hex or `Colors.*` anywhere.
///
/// ```dart
/// Badge('Active', tone: BadgeTone.success)
/// Badge('Error', tone: BadgeTone.destructive)
/// Badge('Pending')  // defaults to BadgeTone.neutral
/// ```
@immutable
class Badge extends StatelessWidget {
  /// The label text displayed inside the badge.
  final String label;

  /// The visual tone controlling background and text color.
  ///
  /// Defaults to [BadgeTone.neutral].
  final BadgeTone tone;

  /// Optional caller className appended after the recipe output.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens override the
  /// matching recipe classes while every non-overridden base class survives.
  final String? className;

  /// Creates a [Badge].
  const Badge(
    this.label, {
    super.key,
    this.tone = BadgeTone.neutral,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    return WBadge(
      label,
      className: badgeRecipe(
        variants: {kBadgeToneAxis: tone.name},
        className: className,
      ),
    );
  }
}
