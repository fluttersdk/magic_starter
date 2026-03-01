import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// Visual divider with "Or continue with" text.
///
/// Appears between the primary auth form and social login buttons.
/// Follows the Magic Starter design system with dark mode support.
class MagicStarterSocialDivider extends StatelessWidget {
  const MagicStarterSocialDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-center my-4',
      children: [
        WDiv(
          className: 'flex-1 h-[1px] bg-gray-200 dark:bg-gray-700',
          child: const SizedBox.shrink(),
        ),
        WDiv(
          className: 'px-4',
          child: WText(
            trans('auth.or_continue_with'),
            className: 'text-sm text-gray-500 dark:text-gray-400',
          ),
        ),
        WDiv(
          className: 'flex-1 h-[1px] bg-gray-200 dark:bg-gray-700',
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
