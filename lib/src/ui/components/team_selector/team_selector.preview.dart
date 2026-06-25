import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'team_selector.dart';

/// Static preview for [TeamSelector].
///
/// Renders the selector trigger in default state (no resolver bound, so
/// SizedBox.shrink is shown — to see the full widget, a resolver must be
/// registered). One preview class per file.
class TeamSelectorPreview extends StatelessWidget {
  const TeamSelectorPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-start gap-4 p-6',
      children: const [
        // No resolver bound — renders an empty placeholder in preview.
        TeamSelector(),
        TeamSelector(compact: true),
      ],
    );
  }
}
