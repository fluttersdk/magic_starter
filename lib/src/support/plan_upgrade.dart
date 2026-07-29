import 'package:flutter/foundation.dart';
import 'package:magic/magic.dart';

/// **A refusal the team can fix by upgrading, read off a gated response.**
///
/// The backend answers a plan-gated action with `403` and an `upgrade` block
/// naming the tier that entitles it:
///
/// ```json
/// {
///   "message": "AI monitor analysis is available on the Pro plan and up. Upgrade to use it.",
///   "upgrade": {"required_plan": "pro", "feature": "AI monitor analysis"}
/// }
/// ```
///
/// [fromResponse] returns `null` for anything else, so a caller can branch on
/// "is this an upgrade wall or a real failure" without matching English prose:
///
/// ```dart
/// final PlanUpgradeRequirement? gated = PlanUpgradeRequirement.fromResponse(response);
/// if (gated != null) {
///   UpgradePrompt.show(gated);
///   return;
/// }
/// ```
@immutable
class PlanUpgradeRequirement {
  /// The sentence the backend sent, rendered verbatim so product copy stays
  /// server-side.
  final String message;

  /// Plan catalog id of the lowest entitling tier (`pro`, `business`,
  /// `enterprise`); the same identifier the billing endpoints accept.
  final String requiredPlan;

  /// Human label of the refused feature, e.g. `AI monitor analysis`.
  final String feature;

  /// Creates a [PlanUpgradeRequirement].
  const PlanUpgradeRequirement({
    required this.message,
    required this.requiredPlan,
    required this.feature,
  });

  /// Reads a plan-gate refusal off [response], or `null` when it is not one.
  ///
  /// Requires the `upgrade.required_plan` marker: a 403 without it is an
  /// authorization failure the user cannot buy their way out of (a team-scope
  /// denial, a revoked token), and offering to upgrade there would be a lie.
  static PlanUpgradeRequirement? fromResponse(MagicResponse response) {
    if (response.statusCode != 403) return null;

    final Object? body = response.data;
    if (body is! Map<String, dynamic>) return null;

    final Object? upgrade = body['upgrade'];
    if (upgrade is! Map<String, dynamic>) return null;

    final Object? plan = upgrade['required_plan'];
    if (plan is! String || plan.isEmpty) return null;

    final Object? feature = upgrade['feature'];
    final Object? message = body['message'];

    return PlanUpgradeRequirement(
      message: message is String ? message : '',
      requiredPlan: plan,
      feature: feature is String ? feature : '',
    );
  }

  /// The tier label for display, e.g. `Pro` for `pro`.
  String get planLabel => requiredPlan.isEmpty
      ? requiredPlan
      : '${requiredPlan[0].toUpperCase()}${requiredPlan.substring(1)}';

  /// The query key naming the tier to buy on arrival.
  static const String planQueryKey = 'upgrade';

  /// The query key carrying the one-shot token that makes an arrival fire
  /// checkout exactly once.
  static const String intentQueryKey = 'intent';

  /// The query the billing screen reads to start the upgrade for
  /// [requiredPlan] on arrival, instead of dropping the user on the plan grid
  /// to find the tier themselves.
  ///
  /// Carries a fresh single-use token per call: the billing screen mounts more
  /// than once per arrival (the router rebuilds it on the auth-state refresh)
  /// and both mounts read the same query, so without a token to consume the
  /// arrival opened two checkout sessions. A later Upgrade tap mints a new
  /// token and fires again.
  Map<String, String> billingQueryParameters() => {
        planQueryKey: requiredPlan,
        intentQueryKey: newIntentToken(),
      };

  /// Monotonic sequence appended to every minted token.
  ///
  /// The timestamp alone is not enough. On web `DateTime.now()` resolves to
  /// milliseconds, so `microsecondsSinceEpoch` advances in steps of 1000 and two
  /// calls inside the same millisecond produce an identical token. That is
  /// exactly the case this token exists to distinguish, since the billing screen
  /// mounts twice per arrival and both mounts read the same query.
  static int _intentSequence = 0;

  /// Mints a single-use intent token, unique within the process.
  static String newIntentToken() {
    final int sequence = _intentSequence++;

    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '-${sequence.toRadixString(36)}';
  }
}
