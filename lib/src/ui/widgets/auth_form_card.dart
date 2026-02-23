import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// Consistent card wrapper for all auth forms.
///
/// Provides title, subtitle, optional error banner, theme toggle, and content area.
/// Matches the Uptizm AuthFormCard pattern — constrained width, centered content.
class MagicStarterAuthFormCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? errorMessage;
  final Widget child;

  const MagicStarterAuthFormCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: '''
        rounded-2xl bg-white dark:bg-slate-800
        border border-slate-200 dark:border-slate-700
        p-4 lg:p-8
        flex flex-col items-center
      ''',
      children: [
        // Theme Toggle
        WDiv(
          className: 'w-full flex flex-row justify-end mb-2',
          child: WAnchor(
            onTap: () => context.windTheme.toggleTheme(),
            child: WDiv(
              className: '''
                p-2 rounded-lg duration-150
                bg-transparent hover:bg-gray-100 dark:hover:bg-gray-800
                flex items-center justify-center
              ''',
              child: WIcon(
                Icons.brightness_6_outlined,
                className: 'text-2xl text-gray-500 dark:text-gray-400',
              ),
            ),
          ),
        ),

        // Title
        WText(
          title,
          className:
              'text-2xl font-bold text-slate-900 dark:text-white text-center',
        ),
        const WSpacer(className: 'h-1'),

        // Subtitle
        WText(
          subtitle,
          className: 'text-sm text-slate-600 dark:text-slate-400 text-center',
        ),
        const WSpacer(className: 'h-6'),

        // Error Banner
        if (errorMessage != null) ...[
          WDiv(
            className: '''
              p-3 rounded-xl
              bg-red-50 dark:bg-red-900/30
              border border-red-200 dark:border-red-800
              text-red-700 dark:text-red-300
              text-sm text-center
            ''',
            child: WText(errorMessage!),
          ),
          const WSpacer(className: 'h-4'),
        ],

        // Form Content
        child,
      ],
    );
  }
}
