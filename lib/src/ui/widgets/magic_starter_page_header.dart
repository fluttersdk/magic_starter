import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// Reusable page header for Magic Starter views.
///
/// Matches the [AppPageHeader] standard: full-width, border-b separator,
/// [p-4 lg:p-6] padding, optional [leading] widget, and optional [actions].
class MagicStarterPageHeader extends StatelessWidget {
  /// Required title text.
  final String title;

  /// Optional subtitle text displayed below the title.
  final String? subtitle;

  /// Optional leading widget (e.g. back button).
  final Widget? leading;

  /// Optional trailing action widgets.
  final List<Widget>? actions;

  const MagicStarterPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    return WDiv(
      className:
          'w-full flex flex-col sm:flex-row items-start sm:items-center sm:justify-between gap-4 p-2 lg:p-4 border-b border-gray-200 dark:border-gray-700',
      children: [
        WDiv(
          className: 'flex flex-row items-center gap-3 sm:flex-1 min-w-0',
          children: [
            if (leading != null) leading,
            WDiv(
              className: 'flex flex-col gap-1 flex-1 min-w-0',
              children: [
                WText(
                  title,
                  className:
                      'text-2xl font-bold text-gray-900 dark:text-white truncate',
                ),
                if (subtitle != null)
                  WText(
                    subtitle!,
                    className:
                        'text-sm text-gray-600 dark:text-gray-400 truncate',
                  ),
              ],
            ),
          ],
        ),
        if (actions != null && actions!.isNotEmpty)
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: actions!,
          ),
      ],
    );
  }
}
