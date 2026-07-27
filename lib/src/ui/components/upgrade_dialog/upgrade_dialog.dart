import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:magic/magic.dart';

import '../button/index.dart';
import 'upgrade_dialog.recipe.dart';

/// **Modal body shown when the backend refuses an action for plan reasons.**
///
/// Purely presentational: the caller wraps it in a modal (barrier and
/// positioning are the caller's job), passes the backend's own sentence
/// verbatim, and reacts to [onUpgrade]/[onDismiss] by closing the modal and
/// routing to billing or dropping the refused action. Sibling of
/// `lib/src/ui/components/upgrade_nudge/`: same lock-tile treatment and `ai`
/// accent, scaled up for a dialog body with a two-action row instead of a
/// single inline CTA.
///
/// ### Example:
/// ```dart
/// showDialog<void>(
///   context: context,
///   builder: (context) => Dialog(
///     child: MSUpgradeDialog(
///       message: response.message,
///       requiredPlan: 'Pro',
///       onUpgrade: () {
///         Navigator.of(context).pop();
///         MagicRoute.to('/teams/billing');
///       },
///       onDismiss: () => Navigator.of(context).pop(),
///     ),
///   ),
/// );
/// ```
@immutable
class MSUpgradeDialog extends StatelessWidget {
  /// The backend's own refusal sentence, rendered verbatim.
  final String message;

  /// The tier that unlocks the gated feature, e.g. "Pro".
  final String requiredPlan;

  /// Tapped when "Upgrade" is pressed. The caller closes the modal and routes
  /// to billing.
  final VoidCallback onUpgrade;

  /// Tapped when the quiet dismiss action is pressed. The caller closes the
  /// modal without acting on the refused request.
  final VoidCallback onDismiss;

  /// Optional extra classNames appended to the root slot.
  final String? className;

  /// Creates an [MSUpgradeDialog].
  const MSUpgradeDialog({
    super.key,
    required this.message,
    required this.requiredPlan,
    required this.onUpgrade,
    required this.onDismiss,
    this.className,
  });

  static const IconData _lockIcon = Icons.lock_outline;

  @override
  Widget build(BuildContext context) {
    final slots = upgradeDialogRecipe(variants: const <String, String>{});

    return WDiv(
      className: className == null
          ? slots['root']
          : '${slots['root']} $className',
      children: [
        // Lock tile (the ai signal) + headline + plan line.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WDiv(
              className: slots['tile'],
              child: WIcon(_lockIcon, className: 'text-ai text-xl'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: WDiv(
                className: 'flex flex-col gap-0.5',
                children: [
                  WText(message, className: slots['message']),
                  WText(
                    trans('uptizm.common.upgrade_available_on', {
                      'plan': requiredPlan,
                    }),
                    className: slots['sub'],
                  ),
                ],
              ),
            ),
          ],
        ),

        // Dismiss + upgrade actions.
        WDiv(
          className: slots['actions'],
          children: [
            MSButton(
              intent: ButtonIntent.ghost,
              size: ButtonSize.sm,
              onPressed: onDismiss,
              child: WText(trans('uptizm.common.upgrade_dialog_not_now')),
            ),
            MSButton(
              intent: ButtonIntent.primary,
              size: ButtonSize.sm,
              onPressed: onUpgrade,
              child: WText(trans('uptizm.common.upgrade')),
            ),
          ],
        ),
      ],
    );
  }
}
