import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';
import 'package:magic_starter/magic_starter.dart';

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;
  String? lastMethod;
  String? lastUrl;
  int notificationGetCallCount = 0;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(data: data ?? {}, statusCode: statusCode);
  }

  MagicResponse _respond(String method, String url, {dynamic data}) {
    lastMethod = method;
    lastUrl = url;

    if (method == 'GET' && url == '/notifications') {
      notificationGetCallCount++;
    }

    return nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  }

  void resetTracking() {
    lastMethod = null;
    lastUrl = null;
    notificationGetCallCount = 0;
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => _respond('DELETE', url);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => _respond('GET', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async => _respond('INDEX', resource);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async => _respond('UPLOAD', url, data: data);
}

/// A [CacheStore] held in memory, recording the TTL each key was written with.
class MemoryCacheStore implements CacheStore {
  final Map<String, dynamic> values = {};
  final Map<String, Duration?> ttls = {};
  final List<String> reads = [];

  @override
  dynamic get(String key, {dynamic defaultValue}) {
    reads.add(key);

    return values.containsKey(key) ? values[key] : defaultValue;
  }

  @override
  Future<void> put(String key, dynamic value, {Duration? ttl}) async {
    values[key] = value;
    ttls[key] = ttl;
  }

  @override
  bool has(String key) => values.containsKey(key);

  @override
  Future<void> forget(String key) async => values.remove(key);

  @override
  Future<void> flush() async => values.clear();

  @override
  Future<void> init() async {}
}

class MockGuard implements Guard {
  Authenticatable? _user;
  final ValueNotifier<int> _stateNotifier = ValueNotifier<int>(0);

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  Future<String?> getToken() async => 'mock-token';

  @override
  Future<bool> hasToken() async => _user != null;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    _user = user;
    _stateNotifier.value++;
  }

  @override
  Future<void> logout() async {
    _user = null;
    _stateNotifier.value++;
  }

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {}

  @override
  void setUser(Authenticatable user) => _user = user;

  @override
  ValueNotifier<int> get stateNotifier => _stateNotifier;

  @override
  T? user<T extends Model>() => _user as T?;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNetworkDriver mockDriver;

  setUp(() {
    MagicApp.reset();
    Magic.flush();

    Magic.singleton('network', () => MockNetworkDriver());

    Magic.singleton('log', () => LogManager());
    Config.set('logging', {
      'default': 'console',
      'channels': {
        'console': {'driver': 'console', 'level': 'debug'},
      },
    });

    final mockGuard = MockGuard();
    Magic.singleton('auth', () => AuthManager());
    Auth.manager.forgetGuards();
    Auth.manager.extend('mock', (_) => mockGuard);
    Config.set('auth.defaults.guard', 'mock');
    Config.set('auth.guards', {
      'mock': {'driver': 'mock'},
    });

    Magic.singleton('magic_starter', () => MagicStarterManager());

    MagicStarter.useNavigation(mainItems: const []);

    mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    mockDriver.mockResponse(statusCode: 200, data: {'data': []});
  });

  tearDown(() {
    Auth.manager.forgetGuards();

    try {
      Notify.stopPolling();
    } catch (_) {}
  });

  GoRouter createRouter({required Widget child, bool hideChrome = false}) {
    return GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => hideChrome
              ? MagicStarterHideChrome(
                  child: MagicStarterAppLayout(child: child),
                )
              : MagicStarterAppLayout(child: child),
        ),
      ],
    );
  }

  Widget createApp({required Widget child, bool hideChrome = false}) {
    final router = createRouter(child: child, hideChrome: hideChrome);

    return WindTheme(
      data: WindThemeData(),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('MagicStarterAppLayout dispose', () {
    testWidgets(
      'stops notification polling when layout is disposed and features enabled',
      (tester) async {
        Config.set('magic_starter.features.notifications', true);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, greaterThan(0));

        mockDriver.resetTracking();

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Disposed'))),
        );
        await tester.pumpAndSettle();

        await tester.pump(const Duration(seconds: 31));
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, equals(0));
      },
    );

    testWidgets(
      'does not start notification polling when feature is disabled',
      (tester) async {
        Config.set('magic_starter.features.notifications', false);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, equals(0));

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Disposed'))),
        );
        await tester.pumpAndSettle();

        await tester.pump(const Duration(seconds: 31));
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, equals(0));
      },
    );
  });

  group('layout theme', () {
    testWidgets('sidebar renders with custom sidebarWidth from LayoutTheme', (
      tester,
    ) async {
      // Desktop viewport to ensure sidebar renders.
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(sidebarWidth: 300),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      // The sidebar is wrapped in SizedBox(width: layoutTheme.sidebarWidth).
      final sidebarBox = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .firstWhere(
            (box) => box.width == 300,
            orElse: () => throw TestFailure('No SizedBox with width 300 found'),
          );
      expect(sidebarBox.width, equals(300));
    });

    testWidgets('sidebar uses custom sidebarClassName from LayoutTheme', (
      tester,
    ) async {
      // Desktop viewport to ensure sidebar renders.
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const customClass =
          'h-full flex flex-col bg-zinc-900 border-r border-zinc-700';
      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(sidebarClassName: customClass),
      );

      // Layout reads sidebarClassName at build time — no exception means it
      // consumed the custom class name correctly.
      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      // Verify the custom class is stored on the manager after the call.
      expect(
        MagicStarter.manager.layoutTheme.sidebarClassName,
        equals(customClass),
      );
    });

    testWidgets(
      'useNavigationTheme still affects nav item styling after layout theme change',
      (tester) async {
        // Desktop viewport to ensure sidebar with nav items renders.
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const customActiveClass =
            'active:bg-indigo-100 dark:active:bg-indigo-900';
        const customHoverClass = 'hover:bg-indigo-50 dark:hover:bg-indigo-900';

        // Apply a custom layout theme first.
        MagicStarter.useLayoutTheme(
          const MagicStarterLayoutTheme(sidebarWidth: 280),
        );

        // Then apply a custom navigation theme — must not be overridden.
        MagicStarter.useNavigationTheme(
          const MagicStarterNavigationTheme(
            activeItemClassName: customActiveClass,
            hoverItemClassName: customHoverClass,
          ),
        );

        MagicStarter.useNavigation(
          mainItems: [
            const MagicStarterNavItem(
              icon: Icons.home,
              labelKey: 'Home',
              path: '/',
            ),
          ],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        // Navigation theme values must survive the layout theme change.
        expect(
          MagicStarter.navigationTheme.activeItemClassName,
          equals(customActiveClass),
        );
        expect(
          MagicStarter.navigationTheme.hoverItemClassName,
          equals(customHoverClass),
        );

        // Layout theme change must not reset the sidebar width either.
        expect(MagicStarter.manager.layoutTheme.sidebarWidth, equals(280));
      },
    );
  });

  group('MagicStarterAppLayout mobile header brand', () {
    testWidgets('mobile header renders brandBuilder when set', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const brandKey = Key('custom-brand-builder');
      MagicStarter.useNavigationTheme(
        MagicStarterNavigationTheme(
          brandBuilder: (_) =>
              const SizedBox(key: brandKey, width: 10, height: 10),
        ),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      // Scope to the header row: the ancestor of the menu icon is the mobile
      // header. The drawer also uses brandBuilder, so a global finder cannot
      // prove the header specifically renders it.
      final headerFinder = find
          .ancestor(of: find.byIcon(Icons.menu), matching: find.byType(WDiv))
          .first;

      expect(
        find.descendant(of: headerFinder, matching: find.byKey(brandKey)),
        findsOneWidget,
      );
    });

    testWidgets('mobile header falls back to WText when brandBuilder is null', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      // Scope to the header row: app.name can also appear in the drawer, so
      // a global text finder cannot prove the header fallback specifically.
      final headerFinder = find
          .ancestor(of: find.byIcon(Icons.menu), matching: find.byType(WDiv))
          .first;

      expect(
        find.descendant(
          of: headerFinder,
          matching: find.text(trans('app.name')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('mobile bottom nav renders a registered bottomItem', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Below the lg breakpoint the shell renders the bottom tab bar, which
      // builds one item per registered bottomItem (the semantic-token icon /
      // label styling lives there). '/' is active, exercising the active
      // branch too.
      MagicStarter.useNavigation(
        mainItems: const [],
        bottomItems: const [
          MagicStarterNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            labelKey: 'Overview',
            path: '/',
          ),
        ],
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
    });
  });

  group('MagicStarterAppLayout sidebar navigation scroll', () {
    testWidgets(
      'sidebar does not overflow with many nav items in short viewport',
      (tester) async {
        // Short viewport to trigger overflow scenario.
        tester.view.physicalSize = const Size(1200, 500);
        tester.view.devicePixelRatio = 1.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Register 10+ nav items to exceed viewport height.
        MagicStarter.useNavigation(
          mainItems: [
            for (int i = 0; i < 12; i++)
              MagicStarterNavItem(
                icon: Icons.circle,
                labelKey: 'Nav $i',
                path: '/nav-$i',
              ),
          ],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        // No overflow error means the navigation area scrolls correctly.
        // Verify that the layout rendered without exceptions.
        expect(find.text('Nav 0'), findsOneWidget);
      },
    );
  });

  group('MagicStarterAppLayout notification bell', () {
    // The bell is mounted twice, in the desktop sidebar's user menu and in the
    // mobile header, so both widths are driven: deleting the component without
    // remounting it breaks the shell on every screen size at once.
    testWidgets('mounts the package dropdown in the mobile header', (
      tester,
    ) async {
      Config.set('magic_starter.features.notifications', true);

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationDropdown), findsOneWidget);
    });

    testWidgets('mounts the package dropdown in the desktop sidebar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Config.set('magic_starter.features.notifications', true);

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationDropdown), findsOneWidget);
    });

    testWidgets('renders no bell at all when the feature is disabled', (
      tester,
    ) async {
      Config.set('magic_starter.features.notifications', false);

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationDropdown), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Shell capabilities: navigation breakpoint, compact rail, focus ring, chrome
  // ---------------------------------------------------------------------------

  group('MagicStarterAppLayout shell capabilities', () {
    void useViewport(WidgetTester tester, double width, double height) {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    void useHomeItem() {
      MagicStarter.useNavigation(
        mainItems: const [
          MagicStarterNavItem(icon: Icons.home, labelKey: 'Home', path: '/'),
        ],
      );
    }

    /// True when a [SizedBox] of exactly [width] logical pixels is mounted,
    /// which is how the shell states the sidebar column is on screen.
    bool hasSidebarOfWidth(WidgetTester tester, double width) {
      return tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .any((box) => box.width == width);
    }

    testWidgets(
      'puts the sidebar on screen below lg when navigationBreakpoint is lowered',
      (tester) async {
        useViewport(tester, 700, 800);
        useHomeItem();

        MagicStarter.useLayoutTheme(
          const MagicStarterLayoutTheme(
            navigationBreakpoint: 'sm',
            sidebarExpandedBreakpoint: 'sm',
            sidebarWidth: 300,
          ),
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(hasSidebarOfWidth(tester, 300), isTrue);
        // The mobile header's hamburger belongs to the drawer shell, which this
        // width no longer selects.
        expect(find.byIcon(Icons.menu), findsNothing);
      },
    );

    testWidgets(
      'keeps the drawer shell below lg when navigationBreakpoint is unset',
      (tester) async {
        useViewport(tester, 700, 800);
        useHomeItem();

        MagicStarter.useLayoutTheme(
          const MagicStarterLayoutTheme(sidebarWidth: 300),
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(hasSidebarOfWidth(tester, 300), isFalse);
        expect(find.byIcon(Icons.menu), findsOneWidget);
      },
    );

    testWidgets(
      'renders the compact rail with icons only below sidebarExpandedBreakpoint',
      (tester) async {
        useViewport(tester, 700, 800);
        useHomeItem();

        MagicStarter.useLayoutTheme(
          const MagicStarterLayoutTheme(
            navigationBreakpoint: 'sm',
            sidebarCompactWidth: 64,
          ),
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(hasSidebarOfWidth(tester, 64), isTrue);
        expect(find.byIcon(Icons.home), findsOneWidget);
        expect(find.text('Home'), findsNothing);
      },
    );

    testWidgets('renders labels at the full width once expanded', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);
      useHomeItem();

      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(
          navigationBreakpoint: 'sm',
          sidebarCompactWidth: 64,
        ),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(hasSidebarOfWidth(tester, 256), isTrue);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('applies focusItemClassName to the sidebar nav item', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);
      useHomeItem();

      const focusClass = 'focus:ring-2 focus:ring-amber-500';
      MagicStarter.useNavigationTheme(
        const MagicStarterNavigationTheme(focusItemClassName: focusClass),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      final ringed = tester
          .widgetList<WDiv>(find.byType(WDiv))
          .where(
            (div) => div.className?.contains('focus:ring-amber-500') ?? false,
          );

      expect(ringed, hasLength(1));
    });

    testWidgets(
      'writes no focus tokens into the item when the field is unset',
      (tester) async {
        useViewport(tester, 1280, 800);
        useHomeItem();

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final ringed = tester
            .widgetList<WDiv>(find.byType(WDiv))
            .where((div) => div.className?.contains('focus:') ?? false);

        expect(ringed, isEmpty);
      },
    );

    testWidgets('renders no header and no bottom bar under hidden chrome', (
      tester,
    ) async {
      useViewport(tester, 400, 800);

      MagicStarter.useNavigation(
        mainItems: const [],
        bottomItems: const [
          MagicStarterNavItem(
            icon: Icons.dashboard_outlined,
            labelKey: 'Overview',
            path: '/',
          ),
        ],
      );

      await tester.pumpWidget(
        createApp(child: const SizedBox(), hideChrome: true),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.text('Overview'), findsNothing);
    });

    testWidgets('renders no sidebar under hidden chrome', (tester) async {
      useViewport(tester, 1280, 800);
      useHomeItem();

      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(sidebarWidth: 300),
      );

      await tester.pumpWidget(
        createApp(child: const SizedBox(), hideChrome: true),
      );
      await tester.pumpAndSettle();

      expect(hasSidebarOfWidth(tester, 300), isFalse);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('still renders the route content under hidden chrome', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);

      await tester.pumpWidget(
        createApp(
          child: const SizedBox(key: Key('route-content')),
          hideChrome: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('route-content')), findsOneWidget);
    });

    testWidgets('names the field when navigationBreakpoint is not a Wind key', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);

      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(navigationBreakpoint: 'large'),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect((error as StateError).message, contains('navigationBreakpoint'));
      expect(error.message, contains('large'));
      // The valid keys are in the message, in width order, so the host does
      // not have to go and read the Wind theme to fix the typo.
      expect(error.message, contains('sm, md, lg, xl, 2xl'));
    });

    testWidgets(
      'names the field when sidebarExpandedBreakpoint is not a Wind key',
      (tester) async {
        // A narrow window on purpose: the compact band is only read above
        // navigationBreakpoint, and a typo has to be reported at every width
        // rather than at the one that happens to consult it.
        useViewport(tester, 400, 800);

        MagicStarter.useLayoutTheme(
          const MagicStarterLayoutTheme(sidebarExpandedBreakpoint: 'large'),
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));

        final error = tester.takeException();
        expect(error, isA<StateError>());
        expect(
          (error as StateError).message,
          contains('sidebarExpandedBreakpoint'),
        );
      },
    );

    testWidgets('mounts the compact rail with a team resolver bound', (
      tester,
    ) async {
      useViewport(tester, 700, 800);
      useHomeItem();

      Config.set('magic_starter.features.teams', true);

      final teams = [
        MagicStarterTeam.fromMap({
          'id': 1,
          'name': 'Acme Corp',
          'personal_team': false,
        }),
      ];
      MagicStarter.useTeamResolver(
        currentTeam: () => teams.first,
        allTeams: () => teams,
        onSwitch: (id) async {},
      );

      // The shipped compact width has to hold the compact team selector, whose
      // trigger is the widest thing the rail mounts that the host did not
      // build itself.
      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(navigationBreakpoint: 'sm'),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MSTeamSelector), findsOneWidget);
      // Compact, so the team name is dropped and only its initial is drawn.
      expect(find.text('Acme Corp'), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('mounts the compact rail with a sidebar footer registered', (
      tester,
    ) async {
      useViewport(tester, 700, 800);
      useHomeItem();

      MagicStarter.useSidebarFooter(
        (context) => const SizedBox(key: Key('sidebar-footer'), height: 24),
      );

      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(navigationBreakpoint: 'sm'),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The host's own widget is passed through untouched: only the host knows
      // whether it fits an icon column.
      expect(find.byKey(const Key('sidebar-footer')), findsOneWidget);
    });

    testWidgets('applies focusItemClassName to the bottom nav item', (
      tester,
    ) async {
      useViewport(tester, 400, 800);

      MagicStarter.useNavigation(
        mainItems: const [],
        bottomItems: const [
          MagicStarterNavItem(
            icon: Icons.dashboard_outlined,
            labelKey: 'Overview',
            path: '/',
          ),
        ],
      );

      MagicStarter.useNavigationTheme(
        const MagicStarterNavigationTheme(
          focusItemClassName: 'focus:ring-2 focus:ring-amber-500',
        ),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      final ringed = tester
          .widgetList<WDiv>(find.byType(WDiv))
          .where(
            (div) => div.className?.contains('focus:ring-amber-500') ?? false,
          );

      expect(ringed, hasLength(1));
    });

    // A screen shaped like a television guide or a media catalogue: a full
    // height column whose body takes the slack and scrolls inside itself. It
    // needs a bounded height from its parent, which is exactly what the
    // shell's scrolling content area cannot give.
    Widget fillShapedScreen() {
      return WDiv(
        key: const Key('fill-screen'),
        className: 'h-full flex flex-col',
        children: [
          WDiv(className: 'h-12', child: WText('Toolbar')),
          WDiv(className: 'flex-1 overflow-y-auto', child: WText('Body')),
        ],
      );
    }

    testWidgets(
      'the default content area scrolls and owns the primary scroll',
      (tester) async {
        useViewport(tester, 400, 800);

        await tester.pumpWidget(
          createApp(child: const SizedBox(key: Key('route-content'))),
        );
        await tester.pumpAndSettle();

        final scrollView = tester.widget<SingleChildScrollView>(
          find
              .ancestor(
                of: find.byKey(const Key('route-content')),
                matching: find.byType(SingleChildScrollView),
              )
              .first,
        );

        expect(scrollView.primary, isTrue);
      },
    );

    testWidgets('a non-scrolling contentClassName leaves the child unscrolled', (
      tester,
    ) async {
      useViewport(tester, 400, 800);

      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(
          contentClassName: 'flex-1 min-h-0',
          contentScrollPrimary: false,
        ),
      );

      await tester.pumpWidget(
        createApp(child: const SizedBox(key: Key('route-content'))),
      );
      await tester.pumpAndSettle();

      // No scroll view above the route child at all, so nothing of the shell's
      // can be attached to the ambient PrimaryScrollController either.
      expect(
        find.ancestor(
          of: find.byKey(const Key('route-content')),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
    });

    testWidgets('a fill-shaped child lays out under a non-scrolling content', (
      tester,
    ) async {
      useViewport(tester, 1440, 900);

      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(
          contentClassName: 'flex-1 min-h-0',
          contentScrollPrimary: false,
        ),
      );

      await tester.pumpWidget(createApp(child: fillShapedScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('fill-screen')), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('the shipped scrolling content area cannot hold that child', (
      tester,
    ) async {
      useViewport(tester, 1440, 900);

      await tester.pumpWidget(createApp(child: fillShapedScreen()));
      await tester.pump();

      // The reason the field exists, asserted rather than described: under the
      // default the same screen is handed an unbounded height and fails to lay
      // out. A host whose screens are all this shape renders nothing.
      //
      // Asserted on the cause rather than on "something threw", so the test
      // cannot go on passing for a different reason. Wind names it here; a
      // real run reports the same thing as a raw infinite-size failure once
      // the assert is compiled out.
      expect(
        tester.takeException().toString(),
        contains('resolves to an unbounded height'),
      );
    });

    test('the new theme fields default to today shell behaviour', () {
      const layout = MagicStarterLayoutTheme();
      const navigation = MagicStarterNavigationTheme();

      expect(layout.navigationBreakpoint, equals('lg'));
      expect(layout.sidebarExpandedBreakpoint, equals('lg'));
      // 80 rather than the compact team selector's own 72, because
      // `sidebarClassName`'s `border-r` takes a pixel out of this box and 72
      // was measured overflowing by exactly 1.
      expect(layout.sidebarCompactWidth, equals(80));
      expect(navigation.focusItemClassName, equals(''));
      expect(layout.contentClassName, equals('flex-1 overflow-y-auto'));
      expect(layout.contentScrollPrimary, isTrue);
    });
  });

  group('MagicStarterAppLayout collapsible sidebar', () {
    const expandIcon = Icons.keyboard_double_arrow_right;
    const collapseIcon = Icons.keyboard_double_arrow_left;
    const preferenceKey = 'magic_starter.sidebar_collapsed';

    void useViewport(WidgetTester tester, double width, double height) {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    void useHomeItem() {
      MagicStarter.useNavigation(
        mainItems: const [
          MagicStarterNavItem(icon: Icons.home, labelKey: 'Home', path: '/'),
        ],
      );
    }

    void useCollapsible({bool collapsedByDefault = true}) {
      MagicStarter.useLayoutTheme(
        MagicStarterLayoutTheme(
          navigationBreakpoint: 'sm',
          sidebarCollapsible: true,
          sidebarCollapsedByDefault: collapsedByDefault,
        ),
      );
    }

    MemoryCacheStore bindCache() {
      final store = MemoryCacheStore();
      Config.set('cache.driver', store);
      Magic.singleton('cache', () => CacheManager());

      return store;
    }

    bool hasSidebarOfWidth(WidgetTester tester, double width) {
      return tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .any((box) => box.width == width);
    }

    testWidgets('starts compact on a wide window when collapsed by default', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);
      useHomeItem();
      useCollapsible();

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(hasSidebarOfWidth(tester, 80), isTrue);
      expect(find.text('Home'), findsNothing);
      expect(find.byIcon(expandIcon), findsOneWidget);
    });

    testWidgets('the toggle expands the rail and collapses it again', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);
      useHomeItem();
      useCollapsible();

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      // 1. Expanded: the labelled width, the label, and the way back.
      await tester.tap(find.byIcon(expandIcon));
      await tester.pumpAndSettle();

      expect(hasSidebarOfWidth(tester, 256), isTrue);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(collapseIcon), findsOneWidget);

      // 2. Collapsed again.
      await tester.tap(find.byIcon(collapseIcon));
      await tester.pumpAndSettle();

      expect(hasSidebarOfWidth(tester, 80), isTrue);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('remembers the choice across a remount through the cache', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);
      useHomeItem();
      useCollapsible();
      final store = bindCache();

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(expandIcon));
      await tester.pumpAndSettle();

      expect(store.values[preferenceKey], isFalse);

      // The file store's own default TTL is an hour, which would quietly hand
      // the viewer the default back the next morning.
      expect(
        store.ttls[preferenceKey],
        greaterThanOrEqualTo(const Duration(days: 365)),
      );

      // A fresh shell reads the stored choice over the theme's default.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(hasSidebarOfWidth(tester, 256), isTrue);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('keeps the choice in memory when no cache is bound', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);
      useHomeItem();
      useCollapsible();

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(expandIcon));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(hasSidebarOfWidth(tester, 256), isTrue);
    });

    testWidgets('never reads the preference for a host that has not opted in', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);
      useHomeItem();
      final store = bindCache();

      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(navigationBreakpoint: 'sm'),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      // Every read dispatches a hit-or-miss event, which a host without the
      // toggle would see logged on every shell mount.
      expect(store.reads, isNot(contains(preferenceKey)));
    });

    testWidgets('offers no toggle when the sidebar is not collapsible', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);
      useHomeItem();

      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(
          navigationBreakpoint: 'sm',
          sidebarCollapsedByDefault: true,
        ),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      // A default the viewer cannot undo would be a rail they are stuck with,
      // so the default only means something on a collapsible sidebar.
      expect(hasSidebarOfWidth(tester, 256), isTrue);
      expect(find.byIcon(expandIcon), findsNothing);
      expect(find.byIcon(collapseIcon), findsNothing);
    });

    testWidgets('offers no toggle in the compact band, which cannot expand', (
      tester,
    ) async {
      useViewport(tester, 700, 800);
      useHomeItem();
      useCollapsible(collapsedByDefault: false);

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(hasSidebarOfWidth(tester, 80), isTrue);
      expect(find.byIcon(expandIcon), findsNothing);
      expect(find.byIcon(collapseIcon), findsNothing);
    });

    testWidgets(
      'renders compactBrandBuilder on the rail, brandBuilder beside labels',
      (tester) async {
        useViewport(tester, 1280, 800);
        useHomeItem();
        useCollapsible();

        MagicStarter.useNavigationTheme(
          MagicStarterNavigationTheme(
            brandBuilder: (_) => const Text('Full brand'),
            compactBrandBuilder: (_) => const Text('Glyph'),
          ),
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(find.text('Glyph'), findsOneWidget);
        expect(find.text('Full brand'), findsNothing);

        await tester.tap(find.byIcon(expandIcon));
        await tester.pumpAndSettle();

        expect(find.text('Full brand'), findsOneWidget);
        expect(find.text('Glyph'), findsNothing);
      },
    );

    testWidgets(
      'centres the compact brand on the rail, as it centres the icons',
      (tester) async {
        useViewport(tester, 1280, 800);
        useHomeItem();
        useCollapsible();

        const glyph = ValueKey<String>('glyph');
        MagicStarter.useNavigationTheme(
          MagicStarterNavigationTheme(
            compactBrandBuilder: (_) =>
                const SizedBox(key: glyph, width: 36, height: 36),
          ),
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        // The shipped brand bar is `justify-between`, which left a lone brand on
        // the bar's left padding, off the line the nav icons below it sit on.
        final railCentre = tester.getCenter(find.byIcon(Icons.home)).dx;

        expect(
          tester.getCenter(find.byKey(glyph)).dx,
          closeTo(railCentre, 0.5),
        );
      },
    );

    testWidgets(
      'takes a compact brand that is already a flex child without a crash',
      (tester) async {
        useViewport(tester, 1280, 800);
        useHomeItem();
        useCollapsible();

        // The shape a host reached for to centre its glyph before the bar did:
        // a `flex-1` root. Wrapped in a second flex parent it throws "Incorrect
        // use of ParentDataWidget" on every rail frame.
        MagicStarter.useNavigationTheme(
          MagicStarterNavigationTheme(
            compactBrandBuilder: (_) => const WDiv(
              className: 'flex-1 flex justify-center',
              child: SizedBox(width: 36, height: 36),
            ),
          ),
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('bounds a compact brand wider than the rail to the rail', (
      tester,
    ) async {
      useViewport(tester, 1280, 800);
      useHomeItem();
      useCollapsible();

      // What the bar offers the brand, read where the brand lays out. A row
      // that neither distributes space nor wraps its child hands it an
      // unbounded width, and a brand that fills what it is offered then runs
      // off the rail.
      double? offered;
      MagicStarter.useNavigationTheme(
        MagicStarterNavigationTheme(
          compactBrandBuilder: (_) => LayoutBuilder(
            builder: (context, constraints) {
              offered = constraints.maxWidth;

              return const SizedBox(width: 36, height: 36);
            },
          ),
        ),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(offered, isNotNull);
      expect(offered, lessThanOrEqualTo(80));
    });

    testWidgets('names the icon-only toggle for assistive technology', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      useViewport(tester, 1280, 800);
      useHomeItem();
      useCollapsible();

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('nav.expand_sidebar'), findsOneWidget);

      semantics.dispose();
    });

    test('the collapse fields default to a sidebar that never collapses', () {
      const layout = MagicStarterLayoutTheme();
      const navigation = MagicStarterNavigationTheme();

      expect(layout.sidebarCollapsible, isFalse);
      expect(layout.sidebarCollapsedByDefault, isFalse);
      expect(navigation.compactBrandBuilder, isNull);
    });
  });
}
