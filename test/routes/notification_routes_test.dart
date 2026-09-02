import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Test Suite
// ---------------------------------------------------------------------------
//
// The notification screens live in `magic_notifications`; this package keeps
// the routes. So the contract under test is the SEAM: the two paths, the
// `layout.app` group, the package views resolved through `Notify.view`, the
// host page geometry wrapped around them, and the back route the package
// cannot know by itself.

/// Returns the registered [RouteDefinition] whose `fullPath` matches [path].
///
/// Routes registered inside a `MagicRoute.group(layout: ...)` are collected
/// into a [LayoutDefinition] rather than the flat `routes` list, so both the
/// top-level routes and every layout's children are scanned.
RouteDefinition? routeFor(String path) {
  for (final route in MagicRouter.instance.routes) {
    if (route.fullPath == path) {
      return route;
    }
  }

  for (final layout in MagicRouter.instance.mergedLayouts) {
    for (final route in layout.children) {
      if (route.fullPath == path) {
        return route;
      }
    }
  }

  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();

    // The registry is a static singleton on the facade, so a registration from
    // a previous case would otherwise certify a mount this case never made.
    //
    // `forgetView()` rather than `clear()`: clearing empties the registry and
    // leaves it empty, which is NOT the state an app boots with. The package
    // seeds its own two screens on the first read of `Notify.view`, so a suite
    // running against a cleared registry cannot see a mount decision that turns
    // on those defaults being present, and that is precisely the decision
    // `_mountIfAbsent` makes.
    Notify.forgetView();

    Config.set('magic_starter.features.notifications', true);
    setUpMagicStarterForTests();
  });

  tearDown(() {
    Http.unfake();
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: child),
      ),
    );
  }

  /// Fakes both endpoints the two screens hit on mount.
  void fakeNotificationEndpoints() {
    Http.fake((request) {
      return MagicResponse(
        data: <String, dynamic>{
          'data': <String, dynamic>{
            'incident_opened': <String, dynamic>{
              'label': 'Incident opened',
              'channels': <String, dynamic>{
                'push': <String, dynamic>{'enabled': false, 'locked': false},
              },
            },
          },
          'meta': <String, dynamic>{'push_provisioned': true},
        },
        statusCode: 200,
      );
    });
  }

  group('registerMagicStarterNotificationRoutes', () {
    test('registers the notification list at the notifications prefix', () {
      registerMagicStarterNotificationRoutes();

      final list = routeFor(MagicStarterConfig.notificationsRoute());
      expect(list, isNotNull);
      expect(list!.transitionType, RouteTransition.none);
    });

    test('keeps the preferences page at /settings/notifications', () {
      registerMagicStarterNotificationRoutes();

      // The literal path, not just the config accessor: the URL is the
      // contract a host has already linked to and bookmarked.
      expect(
        MagicStarterConfig.notificationPreferencesRoute(),
        '/settings/notifications',
      );
      expect(
        routeFor(MagicStarterConfig.notificationPreferencesRoute()),
        isNotNull,
      );
    });

    test('registers neither route when the feature is off', () {
      Config.set('magic_starter.features.notifications', false);

      registerMagicStarterNotificationRoutes();

      expect(routeFor(MagicStarterConfig.notificationsRoute()), isNull);
      expect(
        routeFor(MagicStarterConfig.notificationPreferencesRoute()),
        isNull,
      );
    });

    testWidgets('the preferences route builds the package view inside the '
        'host page geometry', (tester) async {
      fakeNotificationEndpoints();
      registerMagicStarterNotificationRoutes();

      final route = routeFor(
        MagicStarterConfig.notificationPreferencesRoute(),
      )!;

      await tester.pumpWidget(wrap(route.buildWidget(const {})));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NotificationPreferencesView), findsOneWidget);
      // The width cap and the edge margins come from the host, and the package
      // cannot resolve them; the mount point is what restores them.
      expect(find.byType(MSPageContainer), findsOneWidget);

      final view = tester.widget<NotificationPreferencesView>(
        find.byType(NotificationPreferencesView),
      );
      expect(view.backRoute, MagicStarterConfig.settingsHubRoute());
    });

    testWidgets('the list route builds the package view inside the host page '
        'geometry', (tester) async {
      fakeNotificationEndpoints();
      registerMagicStarterNotificationRoutes();

      final route = routeFor(MagicStarterConfig.notificationsRoute())!;

      await tester.pumpWidget(wrap(route.buildWidget(const {})));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NotificationsListView), findsOneWidget);
      expect(find.byType(MSPageContainer), findsOneWidget);
    });

    testWidgets('the list route wires the delete affordance', (tester) async {
      // The row renders its delete control only when `onDelete` is non-null,
      // and this registration replaces the package's own default, so a null
      // here leaves `Notify.deleteNotification` and the backend route behind it
      // with no surface anywhere in the ecosystem. Asserted on the parameter
      // rather than by hunting the control, because the control lives in
      // `magic_notifications` and its markup is that package's to change.
      fakeNotificationEndpoints();
      registerMagicStarterNotificationRoutes();

      final route = routeFor(MagicStarterConfig.notificationsRoute())!;

      await tester.pumpWidget(wrap(route.buildWidget(const {})));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final NotificationsListView view = tester.widget<NotificationsListView>(
        find.byType(NotificationsListView),
      );

      expect(view.onDelete, isNotNull);
    });

    testWidgets('the preferences page is capped at the host page width', (
      tester,
    ) async {
      // A width regression compiles perfectly, so the cap is measured rather
      // than inferred from the widget being present: the package screen fills
      // whatever box it is given, and only the mount point bounds it.
      tester.view.physicalSize = const Size(1800, 900);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeNotificationEndpoints();
      registerMagicStarterNotificationRoutes();

      final route = routeFor(
        MagicStarterConfig.notificationPreferencesRoute(),
      )!;

      await tester.pumpWidget(wrap(route.buildWidget(const {})));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // `max-w-7xl px-4 lg:px-8` from the manager's default geometry: 1280 of
      // column minus 32 of horizontal padding per side.
      final width = tester
          .getSize(find.byType(NotificationPreferencesView))
          .width;
      expect(width, lessThanOrEqualTo(1280));
      expect(width, greaterThan(1000));
    });

    testWidgets('a host registration made after the routes wins', (
      tester,
    ) async {
      fakeNotificationEndpoints();
      registerMagicStarterNotificationRoutes();

      Notify.view.register(
        'notifications.preferences',
        () => const Text('host screen'),
      );

      final route = routeFor(
        MagicStarterConfig.notificationPreferencesRoute(),
      )!;

      await tester.pumpWidget(wrap(route.buildWidget(const {})));
      await tester.pump();

      expect(find.text('host screen'), findsOneWidget);
      expect(find.byType(NotificationPreferencesView), findsNothing);
    });

    testWidgets('a host registration made before the routes wins too', (
      tester,
    ) async {
      fakeNotificationEndpoints();

      // The order the installer actually produces for an adopter who follows
      // the scaffold: the route mount is injected into
      // `route_service_provider.dart` while the scaffold points `Notify.view`
      // work at `AppServiceProvider`, so which boot runs first belongs to the
      // host's provider order and neither file can see it. Registering
      // unconditionally here meant that adopter lost their screen with no
      // error, which is the opposite of what every other default in this
      // package does (`MagicStarterManager._registerDefault`).
      Notify.view.register(
        'notifications.preferences',
        () => const Text('host screen'),
      );

      registerMagicStarterNotificationRoutes();

      final route = routeFor(
        MagicStarterConfig.notificationPreferencesRoute(),
      )!;

      await tester.pumpWidget(wrap(route.buildWidget(const {})));
      await tester.pump();

      expect(find.text('host screen'), findsOneWidget);
      expect(find.byType(NotificationPreferencesView), findsNothing);
    });
  });
}
