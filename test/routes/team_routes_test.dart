import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('registerMagicStarterTeamRoutes', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      MagicRouter.reset();

      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      // Register a dummy layout so makeLayout doesn't throw.
      MagicStarter.view.registerLayout(
        'layout.app',
        (child) => SizedBox(child: child),
      );
    });

    tearDown(() {
      MagicRouter.reset();
    });

    // -----------------------------------------------------------------------
    // Feature gate
    // -----------------------------------------------------------------------

    test('does nothing when team features are disabled', () {
      Config.set('magic_starter.features.teams', false);

      registerMagicStarterTeamRoutes();

      expect(MagicRouter.instance.routes, isEmpty);
      expect(MagicRouter.instance.mergedLayouts, isEmpty);
    });

    test('does nothing when team features config is absent (default false)',
        () {
      registerMagicStarterTeamRoutes();

      expect(MagicRouter.instance.routes, isEmpty);
      expect(MagicRouter.instance.mergedLayouts, isEmpty);
    });

    // -----------------------------------------------------------------------
    // Route registration
    // -----------------------------------------------------------------------

    test('registers 3 routes inside a layout when team features are enabled',
        () {
      Config.set('magic_starter.features.teams', true);

      registerMagicStarterTeamRoutes();

      final layouts = MagicRouter.instance.mergedLayouts;
      expect(layouts, hasLength(1));
      expect(layouts.first.children, hasLength(3));
    });

    test('registers routes with correct default paths', () {
      Config.set('magic_starter.features.teams', true);

      registerMagicStarterTeamRoutes();

      final routes = MagicRouter.instance.mergedLayouts.first.children;
      final paths = routes.map((r) => r.path).toList();

      expect(paths, contains('/teams/create'));
      expect(paths, contains('/teams/settings'));
      expect(paths, contains('/invitations/:token/accept'));
    });

    test('uses custom teams prefix when configured', () {
      Config.set('magic_starter.features.teams', true);
      Config.set('magic_starter.routes.teams_prefix', '/my-teams');

      registerMagicStarterTeamRoutes();

      final routes = MagicRouter.instance.mergedLayouts.first.children;
      final paths = routes.map((r) => r.path).toList();

      expect(paths, contains('/my-teams/create'));
      expect(paths, contains('/my-teams/settings'));
      // Invitation route is NOT prefixed by teamsPrefix.
      expect(paths, contains('/invitations/:token/accept'));
    });

    // -----------------------------------------------------------------------
    // Layout and middleware
    // -----------------------------------------------------------------------

    test('layout uses app layoutId', () {
      Config.set('magic_starter.features.teams', true);

      registerMagicStarterTeamRoutes();

      final layout = MagicRouter.instance.mergedLayouts.first;
      expect(layout.id, equals('app'));
    });

    test('routes inherit auth middleware from group', () {
      Config.set('magic_starter.features.teams', true);

      registerMagicStarterTeamRoutes();

      final routes = MagicRouter.instance.mergedLayouts.first.children;

      for (final route in routes) {
        expect(route.middlewares, contains('auth'));
      }
    });

    // -----------------------------------------------------------------------
    // Transition
    // -----------------------------------------------------------------------

    test('all routes use RouteTransition.none', () {
      Config.set('magic_starter.features.teams', true);

      registerMagicStarterTeamRoutes();

      final routes = MagicRouter.instance.mergedLayouts.first.children;

      for (final route in routes) {
        expect(route.transitionType, equals(RouteTransition.none));
      }
    });
  });
}
