import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'upgrade_nudge.dart';

/// Static variant-matrix preview for [MSUpgradeNudge].
///
/// Covers a reached cap, a locked capability, and the compact (button-less)
/// variant. One preview class per file; discovered by `previews:refresh`.
class UpgradeNudgePreview extends StatelessWidget {
  /// Creates the MSUpgradeNudge variant-matrix preview.
  const UpgradeNudgePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const WDiv(
      className: 'flex flex-col gap-4 p-6 max-w-xl',
      children: [
        MSUpgradeNudge(
          message: "You've reached your 3-responder limit.",
          requiredPlan: 'Business',
        ),
        MSUpgradeNudge(
          message: 'AI Auto mode resolves incidents on its own.',
          requiredPlan: 'Business',
        ),
        MSUpgradeNudge(
          message: '10-second checks need a faster plan.',
          requiredPlan: 'Business',
          compact: true,
        ),
      ],
    );
  }
}
