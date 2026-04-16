import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Consistent card wrapper for all auth forms.
///
/// Provides title, subtitle, optional error banner, theme toggle, and content area.
/// Matches the Magic Starter AuthFormCard pattern — constrained width, centered content.
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
      className: MagicStarter.authTheme.cardClassName,
      children: [
        // Theme Toggle
        WDiv(
          className: 'w-full flex flex-row justify-end mb-2',
          child: WAnchor(
            onTap: () => context.windTheme.toggleTheme(),
            child: WDiv(
              className: MagicStarter.authTheme.themeToggleClassName,
              child: WIcon(
                Icons.brightness_6_outlined,
                className: MagicStarter.authTheme.themeToggleIconClassName,
              ),
            ),
          ),
        ),

        // Title
        WText(
          title,
          className: MagicStarter.authTheme.titleClassName,
        ),
        const WSpacer(className: 'h-1'),

        // Subtitle
        WText(
          subtitle,
          className: MagicStarter.authTheme.subtitleClassName,
        ),
        const WSpacer(className: 'h-6'),

        // Error Banner
        if (errorMessage != null) ...[
          WDiv(
            className: MagicStarter.authTheme.errorBannerClassName,
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
