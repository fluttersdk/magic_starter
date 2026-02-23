import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// Reusable page header for Magic Starter views.
class MagicStarterPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const MagicStarterPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-center justify-between pb-4',
      children: [
        WDiv(
          className: 'flex flex-col gap-1',
          children: [
            WText(
              title,
              className: 'text-2xl font-bold text-gray-900 dark:text-white',
            ),
            if (subtitle != null)
              WText(
                subtitle!,
                className: 'text-sm text-gray-600 dark:text-gray-400',
              ),
          ],
        ),
        if (actions != null)
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: actions!,
          ),
      ],
    );
  }
}
