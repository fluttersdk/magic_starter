import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';
import 'card.recipe.dart';

/// Visual style variants for [Card].
///
/// - [surface] — Default flat card: white/gray-800 background with a subtle border.
/// - [inset] — Recessed appearance: slightly darker background (gray-50/gray-900)
///   with the same border, useful for secondary or nested content sections.
/// - [elevated] — Raised appearance: white/gray-800 background with a drop
///   shadow instead of a border, making the card float above the page.
enum CardVariant {
  /// Default flat card with border (no shadow).
  surface,

  /// Slightly recessed card with a darker background and border.
  inset,

  /// Floating card with a drop shadow and no border.
  elevated,
}

/// A reusable card component for Magic Starter views.
///
/// Provides a consistent background, border, and padding through a
/// [WindRecipe] (`card.recipe.dart`) whose output is byte-identical to the
/// pre-migration `MagicStarterCard` for every variant x [noPadding] combo.
/// Optionally includes a title at the top.
///
/// ### Variant styles
///
/// Pass [variant] to control the visual appearance of the card:
///
/// ```dart
/// Card(
///   variant: CardVariant.elevated,
///   child: ...,
/// )
/// ```
///
/// When [noPadding] is `true`, the card omits its default `p-6` padding from
/// the body so that full-bleed content (e.g. list rows that span edge-to-edge)
/// can be placed inside. The title — if provided — always gets its own
/// `px-6 pt-6 pb-3` padding when [noPadding] is active.
///
/// ### Example — padded card with title:
/// ```dart
/// Card(
///   title: 'Team Settings',
///   child: WFormInput(...),
/// )
/// ```
///
/// ### Example — full-bleed list card:
/// ```dart
/// Card(
///   title: 'Members',
///   noPadding: true,
///   child: WDiv(
///     className: 'flex flex-col',
///     children: rows.map((r) => _buildRow(r)).toList(),
///   ),
/// )
/// ```
@immutable
class Card extends StatelessWidget {
  /// The optional title to display at the top of the card.
  final String? title;

  /// The main content of the card.
  final Widget child;

  /// Optional className to override the default card styling entirely.
  final String? className;

  /// When `true`, removes the default `p-6 gap-4` padding from the card body
  /// so that list rows or other full-bleed content can span edge-to-edge.
  ///
  /// The title (if any) always receives `px-6 pt-6 pb-3` padding so it
  /// aligns visually with padded row content (`px-6`).
  final bool noPadding;

  /// The visual style variant for this card.
  ///
  /// Defaults to [CardVariant.surface] which reproduces the original card
  /// appearance (white/gray-800 background, subtle border, no shadow).
  final CardVariant variant;

  /// Creates a [Card].
  const Card({
    super.key,
    required this.child,
    this.title,
    this.className,
    this.noPadding = false,
    this.variant = CardVariant.surface,
  });

  /// Resolves the root className from the card recipe (theme-driven).
  ///
  /// When [className] is supplied it overrides the recipe output entirely,
  /// preserving the original escape hatch behaviour.
  String _resolveClassName() {
    if (className != null) {
      return className!;
    }

    final recipe = buildCardRecipe(MagicStarter.cardTheme);
    return recipe(
      variants: {
        kCardVariantAxis: variant.name,
        kCardPaddingAxis:
            noPadding ? kCardPaddingNoPadding : kCardPaddingPadded,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: _resolveClassName(),
      children: [
        if (title != null)
          if (noPadding)
            // Full-bleed mode: title needs its own horizontal padding to align
            // with row content that uses px-6.
            WDiv(
              className:
                  MagicStarter.cardTheme.titleNoPaddingContainerClassName,
              child: WText(
                title!,
                className: MagicStarter.cardTheme.titleClassName,
              ),
            )
          else
            // Padded mode: card already provides p-6, title renders directly.
            WText(
              title!,
              className: MagicStarter.cardTheme.titleClassName,
            ),
        child,
      ],
    );
  }
}
