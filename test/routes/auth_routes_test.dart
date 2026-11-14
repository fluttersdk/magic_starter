import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The auth route registered at [path], or `null` when there is none.
RouteDefinition? authRouteAt(String path) {
  final List<RouteDefinition> routes = [
    ...MagicRouter.instance.routes,
    for (final layout in MagicRouter.instance.mergedLayouts) ...layout.children,
  ];

  for (final RouteDefinition route in routes) {
    if (route.fullPath == path) return route;
  }

  return null;
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
  });

  tearDown(() {
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  void register() {
    Magic.singleton('magic_starter', () => MagicStarterManager());
    registerMagicStarterAuthRoutes();
  }

  group('the handoff route', () {
    test('is not registered while the feature is off', () {
      register();

      expect(authRouteAt('/auth/handoff'), isNull);
      expect(MagicStarterManager().view.has('auth.handoff'), isFalse);
    });

    test('is registered with its view while the feature is on', () {
      Config.set('magic_starter.features.handoff', true);
      register();

      final RouteDefinition? route = authRouteAt('/auth/handoff');

      expect(route, isNotNull);
      expect(route!.routeTitle, 'magic_starter.titles.handoff');
      expect(MagicStarterManager().view.has('auth.handoff'), isTrue);
    });

    test('carries neither the guest nor the auth middleware', () {
      Config.set('magic_starter.features.handoff', true);
      register();

      // The login route proves the lookup sees group middleware at all, so the
      // assertion below cannot pass on a route list that never carries any.
      expect(authRouteAt('/auth/login')!.middlewares, contains('guest'));

      final List<dynamic> middlewares = authRouteAt('/auth/handoff')!
          .middlewares;

      expect(middlewares, isNot(contains('guest')));
      expect(middlewares, isNot(contains('auth')));
    });

    test('follows the configured auth prefix', () {
      Config.set('magic_starter.features.handoff', true);
      Config.set('magic_starter.routes.auth_prefix', '/account');
      register();

      expect(authRouteAt('/account/handoff'), isNotNull);
    });
  });
}
