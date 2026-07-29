import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'upgrade_dialog.dart';

/// Static variant-matrix preview for [MSUpgradeDialog].
///
/// Mirrors `upgrade_nudge.preview.dart`'s coverage intent: a short message, a
/// long wrapping one, and every plan label a caller can pass. One preview
/// class per file; discovered by `previews:refresh`.
class UpgradeDialogPreview extends StatelessWidget {
  /// Creates the MSUpgradeDialog variant-matrix preview.
  const UpgradeDialogPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const WDiv(
      className: 'flex flex-col gap-4 p-6 max-w-xl',
      children: [
        MSUpgradeDialog(
          message: "You've reached your 3-responder limit.",
          requiredPlan: 'Pro',
          onUpgrade: _noop,
          onDismiss: _noop,
        ),
        MSUpgradeDialog(
          message:
              'AI Auto mode resolves incidents on its own, without waiting '
              'for a human responder to pick them up first.',
          requiredPlan: 'Business',
          onUpgrade: _noop,
          onDismiss: _noop,
        ),
        MSUpgradeDialog(
          message: '10-second checks need a faster plan.',
          requiredPlan: 'Enterprise',
          onUpgrade: _noop,
          onDismiss: _noop,
        ),
      ],
    );
  }

  static void _noop() {}
}
