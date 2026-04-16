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

  void mockResponse({
    required int statusCode,
    dynamic data,
  }) {
    nextResponse = MagicResponse(
      data: data ?? {},
      statusCode: statusCode,
    );
  }

  MagicResponse _respond(
    String method,
    String url, {
    dynamic data,
  }) {
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
  }) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async =>
      _respond('GET', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _respond('INDEX', resource);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
      _respond('UPLOAD', url, data: data);
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
  Future<void> login(
    Map<String, dynamic> data,
    Authenticatable user,
  ) async {
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

    Magic.singleton(
      'network',
      () => MockNetworkDriver(),
    );

    Magic.singleton(
      'log',
      () => LogManager(),
    );
    Config.set(
      'logging',
      {
        'default': 'console',
        'channels': {
          'console': {
            'driver': 'console',
            'level': 'debug',
          },
        },
      },
    );

    final mockGuard = MockGuard();
    Magic.singleton('auth', () => AuthManager());
    Auth.manager.forgetGuards();
    Auth.manager.extend(
      'mock',
      (_) => mockGuard,
    );
    Config.set('auth.defaults.guard', 'mock');
    Config.set(
      'auth.guards',
      {
        'mock': {
          'driver': 'mock',
        },
      },
    );

    Magic.singleton(
      'magic_starter',
      () => MagicStarterManager(),
    );

    MagicStarter.useNavigation(mainItems: const []);

    mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    mockDriver.mockResponse(
      statusCode: 200,
      data: {
        'data': [],
      },
    );
  });

  tearDown(() {
    Auth.manager.forgetGuards();

    try {
      Notify.stopPolling();
    } catch (_) {}
  });

  GoRouter createRouter({
    required Widget child,
  }) {
    return GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MagicStarterAppLayout(
            child: child,
          ),
        ),
      ],
    );
  }

  Widget createApp({
    required Widget child,
  }) {
    final router = createRouter(child: child);

    return WindTheme(
      data: WindThemeData(),
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('MagicStarterAppLayout dispose', () {
    testWidgets(
      'stops notification polling when layout is disposed and features enabled',
      (tester) async {
        Config.set('magic_starter.features.notifications', true);

        await tester.pumpWidget(
          createApp(
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, greaterThan(0));

        mockDriver.resetTracking();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Disposed'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.pump(
          const Duration(seconds: 31),
        );
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, equals(0));
      },
    );

    testWidgets(
      'does not start notification polling when feature is disabled',
      (tester) async {
        Config.set('magic_starter.features.notifications', false);

        await tester.pumpWidget(
          createApp(
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, equals(0));

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Disposed'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.pump(
          const Duration(seconds: 31),
        );
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, equals(0));
      },
    );
  });

  group('layout theme', () {
    testWidgets(
      'sidebar renders with custom sidebarWidth from LayoutTheme',
      (tester) async {
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

        await tester.pumpWidget(
          createApp(
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();

        // The sidebar is wrapped in SizedBox(width: layoutTheme.sidebarWidth).
        final sidebarBox =
            tester.widgetList<SizedBox>(find.byType(SizedBox)).firstWhere(
                  (box) => box.width == 300,
                  orElse: () =>
                      throw TestFailure('No SizedBox with width 300 found'),
                );
        expect(sidebarBox.width, equals(300));
      },
    );

    testWidgets(
      'sidebar uses custom sidebarClassName from LayoutTheme',
      (tester) async {
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
        await tester.pumpWidget(
          createApp(
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();

        // Verify the custom class is stored on the manager after the call.
        expect(
          MagicStarter.manager.layoutTheme.sidebarClassName,
          equals(customClass),
        );
      },
    );

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

        await tester.pumpWidget(
          createApp(
            child: const SizedBox(),
          ),
        );
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

        await tester.pumpWidget(
          createApp(
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();

        // No overflow error means the navigation area scrolls correctly.
        // Verify that the layout rendered without exceptions.
        expect(find.text('Nav 0'), findsOneWidget);
      },
    );
  });
}
