import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  /// Mounts the view on a router of its own, because it reads its token from
  /// the route and a plain `MaterialApp` has no route state to read.
  Future<void> mountOnRouter(WidgetTester tester) async {
    MagicRoute.page(
      MagicStarterConfig.twoFactorChallengeRoute(),
      () => const MagicStarterTwoFactorChallengeView(),
    );
    MagicRouter.instance.setInitialLocation(
      MagicStarterConfig.twoFactorChallengeRoute(),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: MagicRouter.instance.routerConfig,
        builder: (context, child) => WindTheme(
          data: WindThemeData(),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('MagicStarterTwoFactorChallengeView — slot injection', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      MagicRouter.reset();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Config.set('magic_starter.features.two_factor', true);
      Magic.put(MagicStarterAuthController());
    });

    tearDown(MagicRouter.reset);

    testWidgets('renders header slot when registered', (tester) async {
      MagicStarter.view.slot(
        'auth.two_factor_challenge',
        'header',
        (ctx) => const Text('Custom Header'),
      );

      await mountOnRouter(tester);

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('renders footer slot when registered', (tester) async {
      MagicStarter.view.slot(
        'auth.two_factor_challenge',
        'footer',
        (ctx) => const Text('Custom Footer'),
      );

      await mountOnRouter(tester);

      expect(find.text('Custom Footer'), findsOneWidget);
    });
  });

  group('MagicStarterTwoFactorChallengeView - token', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      MagicRouter.reset();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Config.set('magic_starter.features.two_factor', true);
      Magic.put(MagicStarterAuthController());
    });

    tearDown(() {
      Http.unfake();
      MagicRouter.reset();
      MagicApp.reset();
      Magic.flush();
    });

    testWidgets(
      'submits the token of its own page, not of the page built last',
      (tester) async {
        final List<Object?> bodies = <Object?>[];
        Http.fake((request) {
          bodies.add(request.data);

          return Http.response(<String, dynamic>{}, 422);
        });

        // Two shells, so the router builds the pushed challenge first and the
        // page underneath after it: a read of the router's last-built state then
        // names that page and its own token, not the challenge's.
        MagicRoute.group(
          layout: (child) => Scaffold(body: child),
          routes: () {
            MagicRoute.page('/elsewhere', () => const Text('Elsewhere'));
          },
        );
        MagicRoute.group(
          layoutId: 'guest',
          layout: (child) =>
              Scaffold(body: SingleChildScrollView(child: child)),
          routes: () {
            MagicRoute.page(
              MagicStarterConfig.twoFactorChallengeRoute(),
              () => const MagicStarterTwoFactorChallengeView(),
            ).stacked();
          },
        );
        MagicRouter.instance.setInitialLocation(
          '/elsewhere?two_factor_token=stale',
        );
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: MagicRouter.instance.routerConfig,
            builder: (context, child) =>
                WindTheme(data: WindThemeData(), child: child!),
          ),
        );
        await tester.pumpAndSettle();

        MagicRoute.to(
          MagicStarterConfig.twoFactorChallengeRoute(),
          query: <String, String>{'two_factor_token': 'tok'},
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(MSButton));
        await tester.pumpAndSettle();

        expect(bodies, hasLength(1));
        expect(
          (bodies.single as Map<String, dynamic>)['two_factor_token'],
          'tok',
        );
      },
    );
  });
}
