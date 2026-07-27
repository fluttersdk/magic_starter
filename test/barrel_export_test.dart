// Proves the package's public entry point actually exposes what this release
// added. It imports ONLY `package:magic_starter/magic_starter.dart`: a symbol
// that exists under `lib/src/` but is missing from the barrel is invisible to
// every consumer, and that gap would otherwise surface as a compile failure in
// a downstream app rather than here.
//
// This has to be a `flutter test` rather than a plain Dart entrypoint, because
// magic_starter imports `flutter/widgets` and a bare Dart VM run fails on
// `dart:ui`.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// A minimal implementer, present only to prove the CONTRACT is exported and
/// implementable from outside the package, not just that its name resolves.
class _ExternalScopedController implements SessionScopedController {
  bool didReset = false;

  @override
  Future<void> resetForSession() async {
    didReset = true;
  }
}

void main() {
  group('barrel exports', () {
    test('the plan-gate value object is reachable and parses a gated 403', () {
      // Reachability plus one behavioural call, so the test fails if the export
      // resolves to something that is not the real type.
      final MagicResponse gated = MagicResponse(
        statusCode: 403,
        data: <String, dynamic>{
          'message': 'AI analysis is available on the Pro plan and up.',
          'upgrade': <String, dynamic>{
            'required_plan': 'pro',
            'feature': 'AI analysis',
          },
        },
      );

      final PlanUpgradeRequirement? requirement =
          PlanUpgradeRequirement.fromResponse(gated);

      expect(requirement, isNotNull);
      expect(requirement!.requiredPlan, 'pro');
      expect(requirement.planLabel, 'Pro');
    });

    test('a plain 403 without the marker is not offered as buyable', () {
      // The load-bearing half of the contract: a 403 with no upgrade marker is
      // an authorization denial no purchase fixes.
      final MagicResponse denied = MagicResponse(
        statusCode: 403,
        data: <String, dynamic>{'message': 'This action is unauthorized.'},
      );

      expect(PlanUpgradeRequirement.fromResponse(denied), isNull);
    });

    test('the upgrade prompt is reachable', () {
      expect(UpgradePrompt.showIfGated, isA<Function>());
    });

    test('the session-scope contract is implementable from outside', () async {
      final _ExternalScopedController controller = _ExternalScopedController();

      await controller.resetForSession();

      expect(controller.didReset, isTrue);
      expect(controller, isA<SessionScopedController>());
    });

    test('the session-scope driver is reachable', () {
      expect(SessionScopeSync.isAttached, isFalse);
    });

    test('both middlewares are reachable and construct', () {
      expect(EnsureAuthenticated(), isA<MagicMiddleware>());
      expect(RedirectIfAuthenticated(), isA<MagicMiddleware>());
    });

    test('both upgrade widgets are reachable under their MS names', () {
      // The package namespaces every component with an MS prefix to avoid
      // colliding with Material and with common consumer names, so these must
      // be exported under the prefixed names.
      expect(
        MSUpgradeDialog(
          message: 'Upgrade to continue.',
          requiredPlan: 'Pro',
          onUpgrade: () {},
          onDismiss: () {},
        ),
        isA<Widget>(),
      );
      expect(
        const MSUpgradeNudge(
          message: 'Upgrade to unlock this.',
          requiredPlan: 'pro',
        ),
        isA<Widget>(),
      );
    });
  });
}
