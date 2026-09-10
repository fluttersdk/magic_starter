import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/configuration/magic_starter_config.dart';
import 'package:magic_starter/src/http/controllers/concerns/navigates_routes.dart';

/// Bare host exercising [NavigatesRoutes] in isolation, without pulling in a
/// full controller's HTTP/auth surface.
class _TestHost with NavigatesRoutes {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
    Auth.fake();
  });

  tearDown(() {
    Auth.unfake();
  });

  group('NavigatesRoutes.navigateHome', () {
    testWidgets('targets the stored intended URL when one is set', (
      tester,
    ) async {
      final host = _TestHost();
      MagicRoute.page('/', () => const Text('home'));
      MagicRoute.page('/incidents/123', () => const Text('incident'));

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.setIntendedUrl('/incidents/123');
      host.navigateHome();
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentPath, '/incidents/123');
    });

    testWidgets(
      'falls back to the configured home route when no intent is stored',
      (tester) async {
        final host = _TestHost();
        MagicRoute.page('/', () => const Text('home'));
        MagicRoute.page('/monitors', () => const Text('monitors'));

        MagicRouter.instance.setInitialLocation('/monitors');

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        host.navigateHome();
        await tester.pumpAndSettle();

        expect(
          MagicRouter.instance.currentPath,
          MagicStarterConfig.homeRoute(),
        );
      },
    );

    testWidgets(
      'falls back to the configured home route when the stored intent is '
      'poisoned',
      (tester) async {
        final host = _TestHost();
        MagicRoute.page('/', () => const Text('home'));
        MagicRoute.page('/monitors', () => const Text('monitors'));

        MagicRouter.instance.setInitialLocation('/monitors');

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        // Set directly rather than via a deep link parse, to prove
        // navigateHome itself rejects a non-leading-slash value regardless
        // of how it got stored.
        MagicRouter.instance.setIntendedUrl('https://evil.example/x');
        host.navigateHome();
        await tester.pumpAndSettle();

        expect(
          MagicRouter.instance.currentPath,
          MagicStarterConfig.homeRoute(),
        );
      },
    );
  });
}
