import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Visual divider with "Or continue with" text.
///
/// Appears between the primary auth form and social login buttons.
/// Follows the Magic Starter design system with dark mode support.
class MagicStarterSocialDivider extends StatelessWidget {
  const MagicStarterSocialDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: MagicStarter.authTheme.socialDividerClassName,
      children: [
        WDiv(
          className: MagicStarter.authTheme.socialDividerLineClassName,
          child: const SizedBox.shrink(),
        ),
        WDiv(
          className: 'px-4',
          child: WText(
            trans('auth.or_continue_with'),
            className: MagicStarter.authTheme.socialDividerTextClassName,
          ),
        ),
        WDiv(
          className: MagicStarter.authTheme.socialDividerLineClassName,
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
