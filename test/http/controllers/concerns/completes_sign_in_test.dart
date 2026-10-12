import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/http/controllers/concerns/completes_sign_in.dart';
import 'package:magic_starter/src/http/controllers/concerns/navigates_routes.dart';

/// Bare host exercising [CompletesSignIn] without a controller's state.
class _TestHost with NavigatesRoutes, CompletesSignIn {}

/// A session answer the way `POST /auth/login` and `POST /auth/guest` send it.
Map<String, dynamic> _sessionBody() {
  return {
    'data': {
      'token': 'session-token',
      'user': {'id': 7, 'name': 'Alice'},
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Auth.fake();
  });

  tearDown(() {
    Auth.unfake();
  });

  /// Mounts a router sitting on `/monitors`, away from the home route, so a
  /// navigation home is observable.
  Future<void> pumpRouterAwayFromHome(WidgetTester tester) async {
    MagicRoute.page('/', () => const Text('home'));
    MagicRoute.page('/monitors', () => const Text('monitors'));
    MagicRouter.instance.setInitialLocation('/monitors');

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
    );
    await tester.pumpAndSettle();
  }

  group('CompletesSignIn.completeSignIn', () {
    testWidgets('signs in and goes home by default', (tester) async {
      await pumpRouterAwayFromHome(tester);

      final concluded = await _TestHost().completeSignIn(_sessionBody());
      await tester.pumpAndSettle();

      expect(concluded, isTrue);
      expect(Auth.check(), isTrue);
      expect(MagicRouter.instance.currentPath, '/');
    });

    testWidgets('signs in without moving the viewer when navigate is false', (
      tester,
    ) async {
      await pumpRouterAwayFromHome(tester);
      MagicRouter.instance.setIntendedUrl('/monitors');

      final concluded = await _TestHost().completeSignIn(
        _sessionBody(),
        navigate: false,
      );
      await tester.pumpAndSettle();

      expect(concluded, isTrue);
      expect(Auth.check(), isTrue);
      expect(MagicRouter.instance.currentPath, '/monitors');
      // The intended url is the next interactive sign-in's to read.
      expect(MagicRouter.instance.pullIntendedUrl(), '/monitors');
    });

    test('a body without a session concludes nothing', () async {
      final concluded = await _TestHost().completeSignIn({
        'data': {
          'user': {'id': 7},
        },
      }, navigate: false);

      expect(concluded, isFalse);
      expect(Auth.check(), isFalse);
    });
  });
}
