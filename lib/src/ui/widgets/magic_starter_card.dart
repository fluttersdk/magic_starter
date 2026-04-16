import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Visual style variants for [MagicStarterCard].
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
/// Provides a consistent background, border, and padding.
/// Optionally includes a title at the top.
///
/// ### Variant styles
///
/// Pass [variant] to control the visual appearance of the card:
///
/// ```dart
/// MagicStarterCard(
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
/// MagicStarterCard(
///   title: 'Team Settings',
///   child: WFormInput(...),
/// )
/// ```
///
/// ### Example — full-bleed list card:
/// ```dart
/// MagicStarterCard(
///   title: 'Members',
///   noPadding: true,
///   child: WDiv(
///     className: 'flex flex-col',
///     children: rows.map((r) => _buildRow(r)).toList(),
///   ),
/// )
/// ```
@immutable
class MagicStarterCard extends StatelessWidget {
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

  /// Creates a [MagicStarterCard].
  const MagicStarterCard({
    super.key,
    required this.child,
    this.title,
    this.className,
    this.noPadding = false,
    this.variant = CardVariant.surface,
  });

  String get _variantClasses {
    final theme = MagicStarter.cardTheme;
    switch (variant) {
      case CardVariant.surface:
        return theme.surfaceClassName;
      case CardVariant.inset:
        return theme.insetClassName;
      case CardVariant.elevated:
        return theme.elevatedClassName;
    }
  }

  String get _defaultClassName {
    final theme = MagicStarter.cardTheme;
    final v = _variantClasses;
    return noPadding
        ? 'w-full $v ${theme.borderRadius} overflow-hidden flex flex-col'
        : 'w-full $v ${theme.borderRadius} ${theme.paddingClassName} flex flex-col gap-4';
  }

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: className ?? _defaultClassName,
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
