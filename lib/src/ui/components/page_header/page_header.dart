import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';

/// Reusable page header for Magic Starter views.
///
/// Full-width header with `border-b` separator, responsive `flex-col sm:flex-row`
/// layout, optional [leading], optional [actions], optional [titleSuffix], and
/// an [inlineActions] flag to force a single-row layout.
///
/// ### Example
/// ```dart
/// PageHeader(
///   title: 'Settings',
///   subtitle: 'Manage your account',
///   actions: [Button(onPressed: save, child: const Text('Save'))],
/// )
/// ```
@immutable
class PageHeader extends StatelessWidget {
  /// Required title text.
  final String title;

  /// Optional subtitle text displayed below the title.
  final String? subtitle;

  /// Optional leading widget (e.g. back button).
  final Widget? leading;

  /// Optional trailing action widgets.
  final List<Widget>? actions;

  /// Optional widget rendered inline after the title column.
  final Widget? titleSuffix;

  /// When `true`, the outer container uses `flex-row` instead of the default
  /// responsive `flex-col sm:flex-row` stacked layout.
  final bool inlineActions;

  /// Creates a [PageHeader].
  const PageHeader({
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
        // 1. Title row: optional leading + title column + optional titleSuffix.
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
        // 2. Optional actions row.
        if (actions != null && actions!.isNotEmpty)
          WDiv(
            className: MagicStarter.pageHeaderTheme.actionContainerClassName,
            children: actions!,
          ),
      ],
    );
  }
}
