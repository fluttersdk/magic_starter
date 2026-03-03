import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// A reusable card component for Magic Starter views.
///
/// Provides a consistent background, border, and padding.
/// Optionally includes a title at the top.
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

  /// Optional className to override the default card styling.
  final String? className;

  /// When `true`, removes the default `p-6 gap-4` padding from the card body
  /// so that list rows or other full-bleed content can span edge-to-edge.
  ///
  /// The title (if any) always receives `px-6 pt-6 pb-3` padding so it
  /// aligns visually with padded row content (`px-6`).
  final bool noPadding;

  /// Creates a [MagicStarterCard].
  const MagicStarterCard({
    super.key,
    required this.child,
    this.title,
    this.className,
    this.noPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    final String defaultClassName = noPadding
        ? 'w-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl overflow-hidden flex flex-col'
        : 'w-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl p-6 flex flex-col gap-4';

    return WDiv(
      className: className ?? defaultClassName,
      children: [
        if (title != null)
          if (noPadding)
            // Full-bleed mode: title needs its own horizontal padding to align
            // with row content that uses px-6.
            WDiv(
              className: 'px-6 pt-6 pb-3',
              child: WText(
                title!,
                className:
                    'text-lg font-semibold text-gray-900 dark:text-white',
              ),
            )
          else
            // Padded mode: card already provides p-6, title renders directly.
            WText(
              title!,
              className: 'text-lg font-semibold text-gray-900 dark:text-white',
            ),
        child,
      ],
    );
  }
}
