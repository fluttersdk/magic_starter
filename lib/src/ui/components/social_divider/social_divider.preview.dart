import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'social_divider.dart';

/// Static preview for [SocialDivider].
///
/// Renders the divider in light/dark. One preview class per file.
class SocialDividerPreview extends StatelessWidget {
  const SocialDividerPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: const [
        SocialDivider(),
      ],
    );
  }
}
