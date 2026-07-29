import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../ui/components/upgrade_dialog/index.dart';
import 'plan_upgrade.dart';

/// **The one way a plan wall is surfaced to the user.**
///
/// A gated action used to end in a plain error toast: it named the tier in
/// prose and then left the user to find the billing screen, the plan and the
/// checkout button themselves. This shows the refusal with the action attached,
/// so "Upgrade" lands on billing and starts checkout for exactly the tier the
/// backend named.
///
/// Call [showIfGated] from a controller's non-2xx branch and fall through to
/// the normal error handling when it returns `false`:
///
/// ```dart
/// if (!response.successful) {
///   if (UpgradePrompt.showIfGated(response)) return null;
///   Magic.error(title, response.errorMessage ?? fallback);
///   return null;
/// }
/// ```
abstract final class UpgradePrompt {
  /// Shows the upgrade wall for [requirement].
  ///
  /// "Upgrade" closes the dialog and routes to billing with the plan intent, so
  /// the purchase starts on arrival; dismissing leaves the user exactly where
  /// they were, with the action still un-performed.
  static void show(PlanUpgradeRequirement requirement) {
    MagicFeedback.showCustomDialog<void>(
      MSUpgradeDialog(
        message: requirement.message,
        requiredPlan: requirement.planLabel,
        onUpgrade: () {
          MagicFeedback.closeDialog();
          MagicRoute.to(
            MagicStarterConfig.billingRoute(),
            query: requirement.billingQueryParameters(),
          );
        },
        onDismiss: MagicFeedback.closeDialog,
      ),
    );
  }

  /// Routes to billing and starts the upgrade for the plan catalog id
  /// [requiredPlan], for a surface that already TOLD the user what is gated
  /// (an inline `MSUpgradeNudge`) and only needs the action.
  ///
  /// A blank id means the catalog has not loaded or no tier unlocks the
  /// feature, so this lands on billing without a purchase intent rather than
  /// starting checkout for a tier nobody named.
  static void startUpgrade(String requiredPlan) {
    if (requiredPlan.isEmpty) {
      MagicRoute.to(MagicStarterConfig.billingRoute());

      return;
    }

    MagicRoute.to(
      MagicStarterConfig.billingRoute(),
      query: {
        PlanUpgradeRequirement.planQueryKey: requiredPlan,
        PlanUpgradeRequirement.intentQueryKey:
            PlanUpgradeRequirement.newIntentToken(),
      },
    );
  }

  /// Shows the upgrade wall when [response] is a plan-gate refusal, and reports
  /// whether it was one.
  ///
  /// `false` means the caller owns the failure: a 403 without the upgrade
  /// marker is an authorization denial no purchase fixes, and every other
  /// status is an ordinary error.
  static bool showIfGated(MagicResponse response) {
    final PlanUpgradeRequirement? requirement =
        PlanUpgradeRequirement.fromResponse(response);
    if (requirement == null) return false;

    show(requirement);

    return true;
  }
}
