import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

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

  /// Optional widget rendered inline after the title column, inside the title+leading row.
  final Widget? titleSuffix;

  /// When true, the outer WDiv uses a single-row layout (`flex-row`) instead of
  /// the default responsive `flex-col sm:flex-row` stacked layout.
  final bool inlineActions;

  const MagicStarterPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.titleSuffix,
    this.inlineActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    return WDiv(
      className: inlineActions
          ? MagicStarter.pageHeaderTheme.containerInlineClassName
          : MagicStarter.pageHeaderTheme.containerClassName,
      children: [
        WDiv(
          className: inlineActions
              ? 'flex flex-row items-center gap-3 flex-1 min-w-0'
              : 'flex flex-row items-center gap-3 sm:flex-1 min-w-0',
          children: [
            if (leading != null) leading,
            WDiv(
              className: 'flex flex-col gap-1 flex-1 min-w-0',
              children: [
                WText(
                  title,
                  className: MagicStarter.pageHeaderTheme.titleClassName,
                ),
                if (subtitle != null)
                  WText(
                    subtitle!,
                    className: MagicStarter.pageHeaderTheme.subtitleClassName,
                  ),
              ],
            ),
            if (titleSuffix != null)
              WDiv(
                className: 'flex-shrink-0',
                child: titleSuffix!,
              ),
          ],
        ),
        if (actions != null && actions!.isNotEmpty)
          WDiv(
            className: MagicStarter.pageHeaderTheme.actionContainerClassName,
            children: actions!,
          ),
      ],
    );
  }
}
