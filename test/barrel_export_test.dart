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

    test('the onboarding gate is reachable', () {
      expect(
        MagicStarterOnboarding.vaultKeyFor('tour'),
        'onboarding_tour_done',
      );
    });

    test('the guest claim and its outcomes are reachable', () {
      expect(MagicStarterGuestClaim.tokenKey, 'guest_claim_token');
      expect(MagicStarterGuestClaim.userKey, 'guest_claim_user');
      expect(GuestClaimOutcome.values, hasLength(4));
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

    test('the release models are reachable and parse a feed', () {
      final MagicStarterReleaseFeed feed = MagicStarterReleaseFeed.fromJson(
        <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'version': '1.1.0',
              'ios_build': 15,
              'android_build': 15,
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'new',
                  'text': <String, String>{'en': 'Dark mode'},
                },
              ],
            },
          ],
          'meta': <String, dynamic>{
            'latest_build': <String, dynamic>{'ios': 15, 'android': 16},
          },
        },
      );

      final MagicStarterRelease release = feed.releases.single;

      expect(release.version, '1.1.0');
      expect(release.items.single.type, MagicStarterReleaseItemType.newFeature);
      expect(feed.latestIosBuild, 15);
      expect(feed.latestAndroidBuild, 16);
    });

    test('the releases controller and the app build support are reachable', () {
      expect(MagicStarterReleasesController.readFeed, isA<Function>());
      expect(MagicStarterAppBuild.isStoreInstall, isA<Function>());
      expect(MagicStarterAppBuild.isWeb, isFalse);
    });

    test('PackageInfo, which the app build support answers, is nameable', () {
      final PackageInfo info = PackageInfo(
        appName: 'Example',
        packageName: 'com.example.app',
        version: '1.4.0',
        buildNumber: '14',
      );

      expect(MagicStarterAppBuild.label(info), '1.4.0 (14)');
    });

    test('the update banner component and both widgets are reachable', () {
      expect(
        MSUpdateBanner(
          message: 'A new version is ready.',
          actionLabel: 'Reload',
          onAction: () {},
          dismissLabel: 'Later',
          onDismiss: () {},
        ),
        isA<Widget>(),
      );
      expect(const MagicStarterAppVersion(), isA<Widget>());
      expect(const MagicStarterAppUpdateBanner(), isA<Widget>());
    });

    test('the changelog view is reachable', () {
      expect(const MagicStarterChangelogView(), isA<Widget>());
    });
  });
}
