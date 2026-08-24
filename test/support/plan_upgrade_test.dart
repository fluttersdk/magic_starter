import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/support/plan_upgrade.dart';

void main() {
  MagicResponse gated({
    int status = 403,
    Map<String, dynamic>? upgrade,
    String message = 'AI monitor analysis is available on the Pro plan and up.',
  }) {
    final Map<String, dynamic> data = <String, dynamic>{'message': message};
    if (upgrade != null) {
      data['upgrade'] = upgrade;
    }

    return MagicResponse(data: data, statusCode: status);
  }

  group('PlanUpgradeRequirement.fromResponse', () {
    test('reads the plan wall off a gated 403', () {
      final PlanUpgradeRequirement? requirement =
          PlanUpgradeRequirement.fromResponse(
            gated(
              upgrade: {
                'required_plan': 'pro',
                'feature': 'AI monitor analysis',
              },
            ),
          );

      expect(requirement, isNotNull);
      expect(requirement!.requiredPlan, equals('pro'));
      expect(requirement.feature, equals('AI monitor analysis'));
      expect(requirement.message, contains('Pro plan'));
    });

    test('ignores a 403 that carries no upgrade marker', () {
      // A team-scope denial or a revoked token is not something the user can
      // buy their way out of: offering to upgrade there would be a lie.
      expect(PlanUpgradeRequirement.fromResponse(gated()), isNull);
    });

    test('ignores a non-403 even when it carries an upgrade block', () {
      final MagicResponse response = gated(
        status: 422,
        upgrade: {'required_plan': 'pro', 'feature': 'AI monitor analysis'},
      );

      expect(PlanUpgradeRequirement.fromResponse(response), isNull);
    });

    test('ignores a blank or non-string required_plan', () {
      expect(
        PlanUpgradeRequirement.fromResponse(gated(upgrade: {'feature': 'X'})),
        isNull,
      );
      expect(
        PlanUpgradeRequirement.fromResponse(
          gated(upgrade: {'required_plan': ''}),
        ),
        isNull,
      );
      expect(
        PlanUpgradeRequirement.fromResponse(
          gated(upgrade: {'required_plan': 2}),
        ),
        isNull,
      );
    });

    test('tolerates a missing message and feature', () {
      final MagicResponse response = MagicResponse(
        data: <String, dynamic>{
          'upgrade': {'required_plan': 'business'},
        },
        statusCode: 403,
      );

      final PlanUpgradeRequirement? requirement =
          PlanUpgradeRequirement.fromResponse(response);

      expect(requirement, isNotNull);
      expect(requirement!.requiredPlan, equals('business'));
      expect(requirement.message, isEmpty);
      expect(requirement.feature, isEmpty);
    });
  });

  group('PlanUpgradeRequirement display + routing', () {
    const PlanUpgradeRequirement requirement = PlanUpgradeRequirement(
      message: 'The AI assistant is available on the Business plan and up.',
      requiredPlan: 'business',
      feature: 'The AI assistant',
    );

    test('capitalizes the plan id for display', () {
      expect(requirement.planLabel, equals('Business'));
    });

    test('carries the billing intent that starts the upgrade on arrival', () {
      final Map<String, String> query = requirement.billingQueryParameters();

      expect(query[PlanUpgradeRequirement.planQueryKey], equals('business'));
      expect(query[PlanUpgradeRequirement.intentQueryKey], isNotEmpty);
    });

    test('mints a fresh intent token per call', () {
      // The billing screen mounts twice per arrival and both mounts read the
      // same query, so the token is what makes one arrival fire one checkout
      // while a later Upgrade tap still fires again.
      final String first = requirement
          .billingQueryParameters()[PlanUpgradeRequirement.intentQueryKey]!;
      final String second = requirement
          .billingQueryParameters()[PlanUpgradeRequirement.intentQueryKey]!;

      expect(first, isNot(equals(second)));
    });

    test('every token carries a monotonic sequence, not just a timestamp', () {
      // The previous implementation was the timestamp alone, which collides on
      // WEB: there DateTime.now() resolves to milliseconds, so
      // microsecondsSinceEpoch advances in steps of 1000 and two calls inside
      // one millisecond are identical. That collision cannot be reproduced on
      // the Dart VM, whose clock is genuinely microsecond-resolution, so
      // asserting "a burst has no duplicates" would pass here even with the bug
      // present and guard nothing.
      //
      // This asserts the MECHANISM that makes uniqueness independent of clock
      // resolution instead: a trailing sequence that advances by one per call.
      final List<String> minted = List<String>.generate(
        3,
        (_) => PlanUpgradeRequirement.newIntentToken(),
      );

      final List<int> sequences = minted
          .map((String token) => int.parse(token.split('-').last, radix: 36))
          .toList();

      expect(
        minted.every((String token) => token.contains('-')),
        isTrue,
        reason:
            'a token without a sequence suffix is only as unique as the '
            'platform clock, which on web is one millisecond',
      );
      expect(sequences[1], sequences[0] + 1);
      expect(sequences[2], sequences[1] + 1);
    });
  });
}
