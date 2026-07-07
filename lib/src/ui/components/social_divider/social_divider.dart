import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';

/// Visual divider with "Or continue with" text.
///
/// Appears between the primary auth form and social login buttons.
/// Follows the Magic Starter design system with dark-mode support.
/// Reads className tokens from [MagicStarterAuthTheme] so the consumer can
/// override divider styling via `MagicStarter.useAuthTheme()`.
///
/// ### Example
/// ```dart
/// const MSSocialDivider()
/// ```
@immutable
class MSSocialDivider extends StatelessWidget {
  const MSSocialDivider({super.key});

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
