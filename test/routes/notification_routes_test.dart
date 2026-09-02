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

  /// [wrap], plus the router's navigator key, with the theme ABOVE the app.
  ///
  /// `_confirmThenDelete` shows its dialog against
  /// `MagicRouter.instance.navigatorKey.currentContext`, which is null under
  /// plain [wrap]. That null is a real branch (it refuses), so the two paths
  /// need two different harnesses: [wrap] for the refusal, this for the ask.
  ///
  /// [WindTheme] wraps [MaterialApp] here rather than sitting inside `home`,
  /// which is the order `magic_starter_confirm_dialog_test.dart` uses and the
  /// order `MagicApplication` itself builds (`magic_app_widget.dart`, WindTheme
  /// around the MaterialApp). A dialog is pushed onto the NAVIGATOR, so its
  /// subtree is a sibling of `home` and not a descendant: with the theme inside
  /// `home`, the dialog's own `WDiv` asserts "No WindTheme found in context".
  Widget wrapWithNavigator(Widget child) {
    return WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        navigatorKey: MagicRouter.instance.navigatorKey,
        home: Scaffold(body: child),
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

    testWidgets('a delete nobody could be asked about does not happen', (
      tester,
    ) async {
      // The null-context branch. `wrap` builds no navigator key, so
      // `MagicRouter.instance.navigatorKey.currentContext` is null and there is
      // nowhere to put the question. A destructive action whose question could
      // not be asked has not been answered yes, so nothing may reach the
      // server. Wire the callback straight to `Notify.deleteNotification`
      // again and the DELETE fires here instead.
      final FakeNetworkDriver network = Http.fake((request) {
        return MagicResponse(
          data: const <String, dynamic>{'data': <String, dynamic>{}},
          statusCode: 200,
        );
      });
      registerMagicStarterNotificationRoutes();

      final route = routeFor(MagicStarterConfig.notificationsRoute())!;

      await tester.pumpWidget(wrap(route.buildWidget(const {})));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final NotificationsListView view = tester.widget<NotificationsListView>(
        find.byType(NotificationsListView),
      );

      final bool deleted = await view.onDelete!('n-1');

      network.assertNotSent(
        (MagicRequest request) => request.url.contains('/notifications/n-1'),
      );
      // And it has to SAY nothing happened: the list reloads on a `true`, so
      // answering true here would spend a request re-reading a page that never
      // changed.
      expect(deleted, isFalse);
    });

    testWidgets('a declined delete answers false and sends nothing', (
      tester,
    ) async {
      // The case the bool exists for. Before `onDelete` could answer, the row
      // reloaded after every tap, so saying no to this dialog cost a full
      // GET /notifications for a list that had not changed.
      final FakeNetworkDriver network = Http.fake((request) {
        return MagicResponse(
          data: const <String, dynamic>{'data': <String, dynamic>{}},
          statusCode: 200,
        );
      });
      registerMagicStarterNotificationRoutes();

      final route = routeFor(MagicStarterConfig.notificationsRoute())!;

      await tester.pumpWidget(wrapWithNavigator(route.buildWidget(const {})));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final NotificationsListView view = tester.widget<NotificationsListView>(
        find.byType(NotificationsListView),
      );

      final Future<bool> pending = view.onDelete!('n-1');
      await tester.pumpAndSettle();

      // The raw key: this suite loads no catalogue.
      await tester.tap(find.text('common.cancel'));
      await tester.pumpAndSettle();

      expect(await pending, isFalse);
      network.assertNotSent(
        (MagicRequest request) => request.url.contains('/notifications/n-1'),
      );
    });

    testWidgets('a confirmed delete reaches the server', (tester) async {
      // The other half, and the one the refusal case cannot prove: a callback
      // that returned without calling anything would satisfy that test too.
      final FakeNetworkDriver network = Http.fake((request) {
        return MagicResponse(
          data: const <String, dynamic>{'data': <String, dynamic>{}},
          statusCode: 200,
        );
      });
      registerMagicStarterNotificationRoutes();

      final route = routeFor(MagicStarterConfig.notificationsRoute())!;

      await tester.pumpWidget(wrapWithNavigator(route.buildWidget(const {})));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final NotificationsListView view = tester.widget<NotificationsListView>(
        find.byType(NotificationsListView),
      );

      // Not awaited yet: the future does not complete until the dialog is
      // answered, so awaiting here would deadlock the test against its own
      // unpumped frame.
      final Future<bool> pending = view.onDelete!('n-1');
      await tester.pumpAndSettle();

      // The raw key, because this suite loads no catalogue and `Translator.get`
      // answers the key it cannot find. Same idiom as
      // `magic_starter_confirm_dialog_test.dart`, which taps `common.confirm`.
      await tester.tap(find.text('common.delete'));
      await tester.pumpAndSettle();

      // `true` is what makes the list reload, which a real delete needs: a row
      // leaving page one pulls one up from page two.
      expect(await pending, isTrue);

      network.assertSent(
        (MagicRequest request) => request.url.contains('/notifications/n-1'),
      );
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
