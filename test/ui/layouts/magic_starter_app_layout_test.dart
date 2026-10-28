import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';
import 'package:magic_payments/magic_payments.dart';
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

/// A billing build with a web rail. The campaign banner reads the rail's
/// presence and nothing else from it, so every call is an error.
class _WebRailBilling implements BillingService, WebBillingService {
  @override
  Future<BillingEntitlement> currentEntitlement() => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getPlans() => throw UnimplementedError();

  @override
  Future<List<UsageStat>> getUsage() => throw UnimplementedError();

  @override
  Future<BillingInvoicesPage> getInvoices({String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<PaymentMethod> getPaymentMethod() => throw UnimplementedError();

  @override
  Future<BillingCheckoutSession> checkout({
    required String productKey,
    required String successUrl,
    required String cancelUrl,
  }) => throw UnimplementedError();

  @override
  Future<void> swap({required String productKey}) => throw UnimplementedError();

  @override
  Future<void> cancel() => throw UnimplementedError();

  @override
  Future<String> openPortal({String? returnUrl}) => throw UnimplementedError();
}

/// The three labels the campaign banner renders, so a strip is not laid out
/// around raw keys.
class _CampaignCopyLoader implements TranslationLoader {
  const _CampaignCopyLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async => <String, dynamic>{
    'magic_starter.billing.campaign_see_plans': 'See plans',
    'magic_starter.billing.campaign_dismiss': 'Dismiss',
  };
}

/// The catalogue lines a navigation badge reads, in their two plural forms:
/// the package default and the one a host's item names for itself.
class _NavBadgeCopyLoader implements TranslationLoader {
  const _NavBadgeCopyLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async => <String, dynamic>{
    'nav.badge_count': 'One item|:count items',
    'nav.shopping_open': 'One line to buy|:count lines to buy',
  };
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

    testWidgets('each bottom nav item takes an equal share of the bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // A short label ("Add") must not shrink its tap target to the label's
      // width: the whole slot under it answers the tap, so a thumb that lands
      // beside the word still reaches the destination.
      MagicStarter.useNavigation(
        mainItems: const [],
        bottomItems: const [
          MagicStarterNavItem(
            icon: Icons.home,
            labelKey: 'Overview',
            path: '/',
          ),
          MagicStarterNavItem(icon: Icons.add, labelKey: 'Add', path: '/add'),
          MagicStarterNavItem(
            icon: Icons.place,
            labelKey: 'Places',
            path: '/p',
          ),
          MagicStarterNavItem(icon: Icons.more, labelKey: 'More', path: '/m'),
        ],
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      double slotWidth(String label) => tester
          .getSize(
            find
                .ancestor(of: find.text(label), matching: find.byType(WAnchor))
                .first,
          )
          .width;

      final widths = ['Overview', 'Add', 'Places', 'More'].map(slotWidth);

      expect(widths.toSet(), hasLength(1));
      // The slots cover the bar edge to edge: no strip beside the outermost
      // items is left without a destination.
      expect(widths.reduce((a, b) => a + b), 400);
    });

    testWidgets(
      'mobile bottom nav renders through a slot under its own scope',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

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

        await tester.pumpWidget(createApp(child: const Text('page')));
        await tester.pumpAndSettle();

        // The scope sits inside the layout, above both the bar and the routed
        // child, so a page under the shell can reach the bar's slot.
        final Finder scope = find.descendant(
          of: find.byType(MagicStarterAppLayout),
          matching: find.byType(MagicStarterBottomNavScope),
        );
        expect(scope, findsOneWidget);
        expect(
          find.descendant(of: scope, matching: find.text('page')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(MagicStarterBottomNavSlot),
            matching: find.text('Overview'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a hiding page gets the home indicator inset back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);

      addTearDown(tester.view.reset);

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

      // A Scaffold strips the bottom inset from its body whenever it has a
      // bottom bar, and the slot is always that bar on a phone. A page that
      // hid the bar used to get no bar at all and so kept the inset its
      // docked composer clears the home indicator with.
      double? pageInset;
      await tester.pumpWidget(
        createApp(
          child: MagicStarterHideBottomNav(
            child: Builder(
              builder: (context) {
                pageInset = MediaQuery.paddingOf(context).bottom;

                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(MagicStarterBottomNavSlot)).height, 0);
      expect(pageInset, 34);
    });

    testWidgets('a page above the bar leaves the inset to the bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);

      addTearDown(tester.view.reset);

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

      double? pageInset;
      await tester.pumpWidget(
        createApp(
          child: Builder(
            builder: (context) {
              pageInset = MediaQuery.paddingOf(context).bottom;

              return const SizedBox.expand();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(MagicStarterBottomNavSlot)).height,
        greaterThan(34),
      );
      expect(pageInset, 0);
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

  group('MagicStarterAppLayout app update banner', () {
    // The banner sits above every page, and the toggle is static per app run,
    // so both widths are driven to prove the column keeps one shape.
    setUp(() {
      // No network seam answers, so a mounted banner has nothing to look up.
      MagicStarterAppUpdateBanner.debugFetchDeployedBuild = () async => null;
    });

    tearDown(() {
      MagicStarterAppUpdateBanner.resetForTesting();
      Config.set('magic_starter.features.app_update', false);
    });

    for (final double width in <double>[400, 1280]) {
      testWidgets('mounts no banner at $width when app_update is off', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        Config.set('magic_starter.features.app_update', false);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(find.byType(MagicStarterAppUpdateBanner), findsNothing);
      });

      testWidgets('mounts exactly one banner at $width when app_update is on', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        Config.set('magic_starter.features.app_update', true);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(find.byType(MagicStarterAppUpdateBanner), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('mounts no banner under hidden chrome', (tester) async {
      Config.set('magic_starter.features.app_update', true);

      await tester.pumpWidget(
        createApp(child: const SizedBox(), hideChrome: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterAppUpdateBanner), findsNothing);
    });
  });

  group('MagicStarterAppLayout campaign banner', () {
    setUp(() async {
      Vault.fake();

      // Without copy the two labels are dotted keys with no space to wrap at,
      // wider than the strip itself.
      Translator.instance.setLoader(const _CampaignCopyLoader());
      await Translator.instance.setLocale(const Locale('en'));
    });

    tearDown(() {
      Vault.unfake();
      Config.set('magic_starter.features.billing', false);
    });

    testWidgets('mounts no banner when billing is off', (tester) async {
      Config.set('magic_starter.features.billing', false);

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterCampaignBanner), findsNothing);
    });

    testWidgets('mounts one banner when billing is on, and no controller '
        'leaves it empty', (tester) async {
      Config.set('magic_starter.features.billing', true);

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterCampaignBanner), findsOneWidget);
      expect(find.byType(MSUpdateBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the active campaign above the page', (tester) async {
      Config.set('magic_starter.features.billing', true);
      Magic.put(
        MagicStarterBillingController(
          usageCopy: (List<UsageStat> stats) => stats,
          formatNumber: (int value) => value.toString(),
          billingService: _WebRailBilling(),
        ),
      );
      // The banner hides a campaign that is not running, and the fixture's own
      // window is a fixed calendar week, so the window moves around now.
      final Map<String, dynamic> wire =
          jsonDecode(
                File(
                  '${Directory.current.path}/test/fixtures/wire/billing-campaign.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final DateTime now = DateTime.now().toUtc();
      (wire['data'] as Map<String, dynamic>)
        ..['starts_at'] = now
            .subtract(const Duration(days: 1))
            .toIso8601String()
        ..['ends_at'] = now.add(const Duration(days: 1)).toIso8601String();
      mockDriver.mockResponse(statusCode: 200, data: wire);

      await tester.pumpWidget(createApp(child: const Text('page body')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pro is 20% off this week'), findsOneWidget);
      expect(find.text('page body'), findsOneWidget);
    });

    testWidgets('mounts no banner under hidden chrome', (tester) async {
      Config.set('magic_starter.features.billing', true);

      await tester.pumpWidget(
        createApp(child: const SizedBox(), hideChrome: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterCampaignBanner), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // The sidebar avatar. A host that opens a guest session without awaiting it
  // paints its first frame with no user, so both forms are driven across that
  // gap: a placeholder initial taken from the word "User" is what a person saw
  // there, and the compact rail's const dropdown was not rebuilt with the shell.
  // ---------------------------------------------------------------------------

  group('MagicStarterAppLayout sidebar avatar', () {
    Finder avatarGlyph() => find.descendant(
      of: find.byType(MSAvatar),
      matching: find.byIcon(Icons.person_outline),
    );

    void useViewport(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    Future<void> openGuestSession() {
      return Auth.guard().login(
        {},
        MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Guest',
          'is_guest': true,
        }),
      );
    }

    testWidgets('the expanded form draws a glyph, then the guest initial', (
      tester,
    ) async {
      useViewport(tester, 1280);

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(avatarGlyph(), findsOneWidget);
      expect(find.text('U'), findsNothing);
      expect(find.text('C'), findsNothing);

      await openGuestSession();
      await tester.pumpAndSettle();

      expect(find.text('G'), findsOneWidget);
      expect(avatarGlyph(), findsNothing);
    });

    testWidgets('the compact rail draws a glyph, then the guest initial', (
      tester,
    ) async {
      useViewport(tester, 700);
      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(navigationBreakpoint: 'sm'),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(avatarGlyph(), findsOneWidget);
      expect(find.text('C'), findsNothing);

      await openGuestSession();
      await tester.pumpAndSettle();

      expect(find.text('G'), findsOneWidget);
      expect(avatarGlyph(), findsNothing);
    });

    testWidgets('the expanded form draws the account photo', (tester) async {
      useViewport(tester, 1280);

      await Auth.guard().login(
        {},
        MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Anilcan Cakir',
          'profile_photo_url': 'https://example.test/me.png',
        }),
      );

      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pump();

      expect(
        tester.widget<MSAvatar>(find.byType(MSAvatar)).photoUrl,
        'https://example.test/me.png',
      );
    });

    testWidgets('the expanded form draws the initial on the theme classes', (
      tester,
    ) async {
      useViewport(tester, 1280);
      MagicStarter.useNavigationTheme(
        const MagicStarterNavigationTheme(
          avatarClassName: 'bg-amber-500/10',
          avatarTextClassName: 'text-sm font-bold text-amber-500',
        ),
      );

      await openGuestSession();
      await tester.pumpWidget(createApp(child: const SizedBox()));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<WText>(
              find.ancestor(of: find.text('G'), matching: find.byType(WText)),
            )
            .className,
        'text-sm font-bold text-amber-500',
      );
      expect(
        tester.widget<MSAvatar>(find.byType(MSAvatar)).className,
        contains('bg-amber-500/10'),
      );
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
      'a scrolling content area scrolls and owns the primary scroll',
      (tester) async {
        useViewport(tester, 400, 800);

        // The previous default, still available as an opt-in.
        MagicStarter.useLayoutTheme(
          const MagicStarterLayoutTheme(
            contentClassName: 'flex-1 overflow-y-auto',
            contentScrollPrimary: true,
          ),
        );

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

    testWidgets('the default content area leaves the child unscrolled', (
      tester,
    ) async {
      useViewport(tester, 400, 800);

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

    testWidgets('a fill-shaped child lays out under the default content', (
      tester,
    ) async {
      useViewport(tester, 1440, 900);

      await tester.pumpWidget(createApp(child: fillShapedScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('fill-screen')), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('a scrolling content area cannot hold that child', (
      tester,
    ) async {
      useViewport(tester, 1440, 900);

      MagicStarter.useLayoutTheme(
        const MagicStarterLayoutTheme(
          contentClassName: 'flex-1 overflow-y-auto',
          contentScrollPrimary: true,
        ),
      );

      await tester.pumpWidget(createApp(child: fillShapedScreen()));
      await tester.pump();

      // One of the reasons the default stopped scrolling, asserted rather than
      // described: under a scrolling content area the same screen is handed an
      // unbounded height and fails to lay out, rendering nothing.
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

    test('the theme fields default to the shell behaviour', () {
      const layout = MagicStarterLayoutTheme();
      const navigation = MagicStarterNavigationTheme();

      expect(layout.navigationBreakpoint, equals('lg'));
      expect(layout.sidebarExpandedBreakpoint, equals('lg'));
      // 80 rather than the compact team selector's own 72, because
      // `sidebarClassName`'s `border-r` takes a pixel out of this box and 72
      // was measured overflowing by exactly 1.
      expect(layout.sidebarCompactWidth, equals(80));
      expect(navigation.focusItemClassName, equals(''));
      // A box that does not scroll, so each routed page scrolls itself (#160).
      expect(layout.contentClassName, equals('flex-1 min-h-0'));
      expect(layout.contentScrollPrimary, isFalse);
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

    test('the toggle\'s two labels ship in the install stub', () {
      // The toggle reads these keys; a host installed from the stub gets them,
      // and without them the labelled form shows the raw key. The widget tests
      // above find the keys themselves, so only this ties them to the stub.
      final stub =
          jsonDecode(File('assets/stubs/install/en.stub').readAsStringSync())
              as Map<String, dynamic>;
      final nav = stub['nav'] as Map<String, dynamic>;

      expect(nav['collapse_sidebar'], isA<String>());
      expect(nav['collapse_sidebar'], isNotEmpty);
      expect(nav['expand_sidebar'], isA<String>());
      expect(nav['expand_sidebar'], isNotEmpty);
    });

    test('the collapse fields default to a sidebar that never collapses', () {
      const layout = MagicStarterLayoutTheme();
      const navigation = MagicStarterNavigationTheme();

      expect(layout.sidebarCollapsible, isFalse);
      expect(layout.sidebarCollapsedByDefault, isFalse);
      expect(navigation.compactBrandBuilder, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // A live count on a navigation item
  // ---------------------------------------------------------------------------

  group('MagicStarterAppLayout navigation badge', () {
    const home = MagicStarterNavItem(
      icon: Icons.home,
      labelKey: 'Home',
      path: '/',
    );

    setUp(() async {
      Translator.instance.setLoader(const _NavBadgeCopyLoader());
      await Translator.instance.setLocale(const Locale('en'));
    });

    tearDown(Translator.reset);

    void useViewport(WidgetTester tester, double width, double height) {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    ValueNotifier<int?> liveCount(WidgetTester tester, int? initial) {
      final count = ValueNotifier<int?>(initial);
      addTearDown(count.dispose);

      return count;
    }

    MagicStarterNavItem shopping(ValueListenable<int?> count) {
      return MagicStarterNavItem(
        icon: Icons.shopping_cart,
        labelKey: 'Shopping',
        path: '/shopping',
        badgeCount: count,
      );
    }

    Finder slotOf(String label) {
      return find
          .ancestor(of: find.text(label), matching: find.byType(WAnchor))
          .first;
    }

    group('in the sidebar', () {
      testWidgets('draws the count at the trailing edge of the row', (
        tester,
      ) async {
        useViewport(tester, 1280, 800);
        MagicStarter.useNavigation(
          mainItems: [home, shopping(liveCount(tester, 4))],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final label = tester.getRect(find.text('Shopping'));
        final badge = tester.getRect(find.text('4'));

        expect(find.byType(MSBadge), findsOneWidget);
        expect(badge.left, greaterThan(label.right));
        expect(badge.right, lessThanOrEqualTo(256));
        expect((badge.center.dy - label.center.dy).abs(), lessThan(2));
      });

      testWidgets('draws no badge on an item without one', (tester) async {
        useViewport(tester, 1280, 800);
        MagicStarter.useNavigation(mainItems: const [home]);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(find.byType(MagicStarterNavBadge), findsNothing);
        expect(find.byType(MSBadge), findsNothing);
      });

      testWidgets('hides at null and zero and returns with the count', (
        tester,
      ) async {
        useViewport(tester, 1280, 800);
        final count = liveCount(tester, null);
        MagicStarter.useNavigation(mainItems: [home, shopping(count)]);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(find.byType(MSBadge), findsNothing);

        count.value = 0;
        await tester.pump();
        expect(find.byType(MSBadge), findsNothing);

        count.value = 12;
        await tester.pump();
        expect(find.text('12'), findsOneWidget);
      });

      testWidgets('follows the count without the shell rebuilding', (
        tester,
      ) async {
        useViewport(tester, 1280, 800);
        final count = liveCount(tester, 3);
        MagicStarter.useNavigation(mainItems: [home, shopping(count)]);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        // The notifier is the only thing that moves: no `refreshNotifier`
        // bump, no new `useNavigation`, no route change.
        count.value = 5;
        await tester.pump();

        expect(find.text('3'), findsNothing);
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('caps the number at 99+', (tester) async {
        useViewport(tester, 1280, 800);
        MagicStarter.useNavigation(
          mainItems: [home, shopping(liveCount(tester, 240))],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(find.text('99+'), findsOneWidget);
      });

      testWidgets('folds the count into the name of the item', (tester) async {
        final handle = tester.ensureSemantics();
        useViewport(tester, 1280, 800);
        MagicStarter.useNavigation(
          mainItems: [home, shopping(liveCount(tester, 4))],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(slotOf('Shopping'));

        expect(node.label, contains('Shopping'));
        expect(node.label, contains('4 items'));
        // The drawn "4" is not read a second time beside the sentence.
        expect(node.label, isNot(matches(RegExp(r'(^|\n)4(\n|$)'))));
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);

        handle.dispose();
      });

      testWidgets('reads the label key the item names', (tester) async {
        final handle = tester.ensureSemantics();
        useViewport(tester, 1280, 800);
        MagicStarter.useNavigation(
          mainItems: [
            MagicStarterNavItem(
              icon: Icons.shopping_cart,
              labelKey: 'Shopping',
              path: '/shopping',
              badgeCount: liveCount(tester, 4),
              badgeLabelKey: 'nav.shopping_open',
            ),
          ],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(slotOf('Shopping')).label,
          contains('4 lines to buy'),
        );

        handle.dispose();
      });

      testWidgets('draws on a system item too', (tester) async {
        useViewport(tester, 1280, 800);
        MagicStarter.useNavigation(
          mainItems: const [home],
          systemItems: [shopping(liveCount(tester, 6))],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(find.text('6'), findsOneWidget);
      });

      testWidgets('draws in the drawer below the sidebar breakpoint', (
        tester,
      ) async {
        useViewport(tester, 400, 800);
        MagicStarter.useNavigation(
          mainItems: [home, shopping(liveCount(tester, 4))],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();
        expect(find.byType(MSBadge), findsNothing);

        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();

        expect(find.text('4'), findsOneWidget);
      });
    });

    group('on the compact rail', () {
      testWidgets('sits on the corner of the icon', (tester) async {
        useViewport(tester, 700, 800);
        MagicStarter.useLayoutTheme(
          const MagicStarterLayoutTheme(
            navigationBreakpoint: 'sm',
            sidebarCompactWidth: 64,
          ),
        );
        MagicStarter.useNavigation(
          mainItems: [home, shopping(liveCount(tester, 4))],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final icon = tester.getRect(find.byIcon(Icons.shopping_cart));
        final badge = tester.getRect(find.text('4'));

        expect(find.text('Shopping'), findsNothing);
        expect(badge.center.dx, greaterThan(icon.center.dx));
        expect(badge.center.dy, lessThan(icon.center.dy));
        expect(badge.right, lessThanOrEqualTo(64));
      });

      testWidgets('does not move the icon', (tester) async {
        useViewport(tester, 700, 800);
        MagicStarter.useLayoutTheme(
          const MagicStarterLayoutTheme(
            navigationBreakpoint: 'sm',
            sidebarCompactWidth: 64,
          ),
        );
        final count = liveCount(tester, 0);
        MagicStarter.useNavigation(mainItems: [home, shopping(count)]);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final before = tester.getRect(find.byIcon(Icons.shopping_cart));

        count.value = 4;
        await tester.pump();

        expect(tester.getRect(find.byIcon(Icons.shopping_cart)), before);
      });
    });

    group('on the bottom bar', () {
      testWidgets('sits on the corner of the icon inside its slot', (
        tester,
      ) async {
        useViewport(tester, 400, 800);
        MagicStarter.useNavigation(
          mainItems: const [],
          bottomItems: [home, shopping(liveCount(tester, 4))],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final icon = tester.getRect(find.byIcon(Icons.shopping_cart));
        final badge = tester.getRect(find.text('4'));
        final slot = tester.getRect(slotOf('Shopping'));

        expect(badge.center.dx, greaterThan(icon.center.dx));
        expect(badge.center.dy, lessThan(icon.center.dy));
        expect(badge.right, lessThanOrEqualTo(slot.right));
        expect(badge.top, greaterThanOrEqualTo(slot.top));
      });

      testWidgets('leaves the height of the bar as it was', (tester) async {
        useViewport(tester, 400, 800);
        final count = liveCount(tester, 0);
        MagicStarter.useNavigation(
          mainItems: const [],
          bottomItems: [home, shopping(count)],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final before = tester.getSize(slotOf('Shopping'));

        count.value = 4;
        await tester.pump();

        expect(tester.getSize(slotOf('Shopping')), before);
        expect(tester.getSize(slotOf('Home')), before);
      });

      testWidgets('follows the count and caps it', (tester) async {
        useViewport(tester, 400, 800);
        final count = liveCount(tester, 2);
        MagicStarter.useNavigation(
          mainItems: const [],
          bottomItems: [home, shopping(count)],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);

        count.value = 100;
        await tester.pump();
        expect(find.text('99+'), findsOneWidget);

        count.value = null;
        await tester.pump();
        expect(find.byType(MSBadge), findsNothing);
      });

      testWidgets('folds the count into the name of the item', (tester) async {
        final handle = tester.ensureSemantics();
        useViewport(tester, 400, 800);
        MagicStarter.useNavigation(
          mainItems: const [],
          bottomItems: [home, shopping(liveCount(tester, 4))],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(slotOf('Shopping'));

        expect(node.label, contains('Shopping'));
        expect(node.label, contains('4 items'));
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);

        handle.dispose();
      });
    });

    // The layout tests above read rects, and a rect says where a pill is laid
    // out, not what reached the screen. These render the real shell to an
    // image and look for the pill's own pixels, so a clip that cuts the pill
    // anywhere between the icon and the window fails them.
    group('painted', () {
      /// Pure magenta, set through `badgeClassName`: no other pixel of the
      /// shell is this colour, and the default neutral tone resolves to nothing
      /// under a bare `WindThemeData`, so only this fill can be searched for.
      const fill = Color(0xFFFF00FF);
      const fillClassName = 'bg-[#ff00ff]';

      /// The bounding box of every pixel the shell painted in [fill], or null
      /// when none was.
      Future<Rect?> paintedExtent(WidgetTester tester, GlobalKey key) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = (await tester.runAsync(image.toByteData))!;
        final r = (fill.r * 255).round();
        final g = (fill.g * 255).round();
        final b = (fill.b * 255).round();

        int? left, top, right, bottom;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final at = (y * image.width + x) * 4;
            final drawn =
                bytes.getUint8(at) == r &&
                bytes.getUint8(at + 1) == g &&
                bytes.getUint8(at + 2) == b &&
                bytes.getUint8(at + 3) == 255;
            if (!drawn) continue;

            left = left == null ? x : (x < left ? x : left);
            top = top == null ? y : (y < top ? y : top);
            right = right == null ? x : (x > right ? x : right);
            bottom = bottom == null ? y : (y > bottom ? y : bottom);
          }
        }

        image.dispose();
        if (left == null) return null;

        return Rect.fromLTRB(
          left.toDouble(),
          top!.toDouble(),
          right! + 1.0,
          bottom! + 1.0,
        );
      }

      /// Expects the pixels drawn in [fill] to cover [pill] edge to edge,
      /// give or take the two pixels the rounded ends fade over.
      void expectPaintedWhole(Rect pill, Rect? painted) {
        expect(painted, isNotNull, reason: 'the pill painted no pixel');
        expect(painted!.left, closeTo(pill.left, 2), reason: 'left edge');
        expect(painted.right, closeTo(pill.right, 2), reason: 'right edge');
        expect(painted.top, closeTo(pill.top, 2), reason: 'top edge');
        expect(painted.bottom, closeTo(pill.bottom, 2), reason: 'bottom edge');
      }

      Future<void> mountPainted(WidgetTester tester, GlobalKey key) async {
        MagicStarter.useNavigationTheme(
          const MagicStarterNavigationTheme(badgeClassName: fillClassName),
        );

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: createApp(child: const SizedBox()),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final railWidth in [64.0, 80.0]) {
        testWidgets('a 99+ pill is painted whole on a ${railWidth}px rail', (
          tester,
        ) async {
          useViewport(tester, 700, 800);
          MagicStarter.useLayoutTheme(
            MagicStarterLayoutTheme(
              navigationBreakpoint: 'sm',
              sidebarCompactWidth: railWidth,
            ),
          );
          // First in the rail, so the pill rides the top of the scrolling
          // column it is clipped by.
          MagicStarter.useNavigation(
            mainItems: [shopping(liveCount(tester, 120)), home],
          );
          final key = GlobalKey();

          await mountPainted(tester, key);

          final pill = tester.getRect(find.byType(MSBadge));
          final icon = tester.getRect(find.byIcon(Icons.shopping_cart));

          // Without an overhang there is nothing for a clip to cut.
          expect(pill.right, greaterThan(icon.right));
          expect(pill.left, lessThan(icon.left));
          expect(pill.right, lessThanOrEqualTo(railWidth));
          expectPaintedWhole(pill, await paintedExtent(tester, key));
        });
      }

      testWidgets('a 99+ pill is painted whole on the last bottom bar slot', (
        tester,
      ) async {
        useViewport(tester, 390, 800);
        // Last in the bar, so the pill rides the right edge of the window and
        // the slot's own clip.
        MagicStarter.useNavigation(
          mainItems: const [],
          bottomItems: [
            home,
            const MagicStarterNavItem(
              icon: Icons.add,
              labelKey: 'Add',
              path: '/add',
            ),
            const MagicStarterNavItem(
              icon: Icons.place,
              labelKey: 'Places',
              path: '/p',
            ),
            shopping(liveCount(tester, 120)),
          ],
        );
        final key = GlobalKey();

        await mountPainted(tester, key);

        final pill = tester.getRect(find.byType(MSBadge));
        final icon = tester.getRect(find.byIcon(Icons.shopping_cart));

        expect(pill.right, greaterThan(icon.right));
        expect(pill.left, lessThan(icon.left));
        expect(pill.right, lessThanOrEqualTo(390));
        expectPaintedWhole(pill, await paintedExtent(tester, key));
      });

      testWidgets('a single digit is painted whole on the bottom bar', (
        tester,
      ) async {
        useViewport(tester, 390, 800);
        MagicStarter.useNavigation(
          mainItems: const [],
          bottomItems: [home, shopping(liveCount(tester, 4))],
        );
        final key = GlobalKey();

        await mountPainted(tester, key);

        expectPaintedWhole(
          tester.getRect(find.byType(MSBadge)),
          await paintedExtent(tester, key),
        );
      });
    });

    group('label room', () {
      const stock = MagicStarterNavItem(
        icon: Icons.inventory_2,
        labelKey: 'Stock',
        path: '/stock',
      );

      /// The width the label's own flex slot is given, which is what the row
      /// has left for the text once its icon, gaps and badge are placed.
      double labelRoom(WidgetTester tester, String label) {
        return tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(Expanded),
                  )
                  .first,
            )
            .width;
      }

      testWidgets('a hidden badge costs the label nothing', (tester) async {
        useViewport(tester, 1280, 800);
        final count = liveCount(tester, 0);
        MagicStarter.useNavigation(mainItems: [shopping(count), stock]);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        expect(labelRoom(tester, 'Shopping'), labelRoom(tester, 'Stock'));

        count.value = null;
        await tester.pump();
        expect(labelRoom(tester, 'Shopping'), labelRoom(tester, 'Stock'));
      });

      testWidgets('a shown badge takes its pill and the space before it', (
        tester,
      ) async {
        useViewport(tester, 1280, 800);
        final count = liveCount(tester, 7);
        MagicStarter.useNavigation(mainItems: [shopping(count), stock]);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final badge = tester.getRect(find.byType(MSBadge));
        final label = tester.getRect(
          find
              .ancestor(
                of: find.text('Shopping'),
                matching: find.byType(Expanded),
              )
              .first,
        );

        // The badge's box is everything the row gave it, margin included.
        expect(
          labelRoom(tester, 'Shopping') + badge.width,
          labelRoom(tester, 'Stock'),
        );
        expect(badge.left, label.right);
        // 12 px of margin the pill brings, then the 8 px of its own padding.
        expect(tester.getRect(find.text('7')).left - label.right, 12 + 8);
      });

      testWidgets('the room comes back when the count goes to zero', (
        tester,
      ) async {
        useViewport(tester, 1280, 800);
        final count = liveCount(tester, 7);
        MagicStarter.useNavigation(mainItems: [shopping(count), stock]);

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();
        expect(
          labelRoom(tester, 'Shopping'),
          lessThan(labelRoom(tester, 'Stock')),
        );

        count.value = 0;
        await tester.pump();

        expect(labelRoom(tester, 'Shopping'), labelRoom(tester, 'Stock'));
      });
    });

    group('theme', () {
      test('leaves the badge on its own recipe by default', () {
        expect(const MagicStarterNavigationTheme().badgeClassName, isEmpty);
      });

      testWidgets('appends badgeClassName to the badge', (tester) async {
        useViewport(tester, 1280, 800);
        MagicStarter.useNavigationTheme(
          const MagicStarterNavigationTheme(
            badgeClassName: 'bg-primary text-on-primary',
          ),
        );
        MagicStarter.useNavigation(
          mainItems: [home, shopping(liveCount(tester, 4))],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final badge = tester.widget<MSBadge>(find.byType(MSBadge));

        // The labelled row adds the space that sets the pill off its label,
        // ahead of the host's classes so theirs still win their families.
        expect(badge.className, 'ml-3 bg-primary text-on-primary');
      });

      testWidgets('passes badgeClassName as it is where there is no row', (
        tester,
      ) async {
        useViewport(tester, 390, 800);
        MagicStarter.useNavigationTheme(
          const MagicStarterNavigationTheme(
            badgeClassName: 'bg-primary text-on-primary',
          ),
        );
        MagicStarter.useNavigation(
          mainItems: const [],
          bottomItems: [home, shopping(liveCount(tester, 4))],
        );

        await tester.pumpWidget(createApp(child: const SizedBox()));
        await tester.pumpAndSettle();

        final badge = tester.widget<MSBadge>(find.byType(MSBadge));

        expect(badge.className, 'bg-primary text-on-primary');
      });
    });
  });

  // ---------------------------------------------------------------------------
  // A page left under a stacked route (#160)
  // ---------------------------------------------------------------------------

  group('MagicStarterAppLayout with a page under a stacked route', () {
    testWidgets('the hidden page takes live rebuilds without breaking layout', (
      tester,
    ) async {
      // In a go_router shell the route child is the nested Navigator. A
      // content box that scrolls hands its Overlay an unbounded height, the
      // Overlay then never lays the hidden page out again, and that page's
      // second rebuild fails `_debugRelayoutBoundaryAlreadyMarkedNeedsLayout`
      // and leaves the tree inconsistent (flutter/flutter#193247). Under the
      // shipped content box the Navigator gets a bounded height instead.
      final ValueNotifier<int> reading = ValueNotifier<int>(0);
      addTearDown(reading.dispose);

      final GoRouter router = GoRouter(
        initialLocation: '/list',
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                MagicStarterAppLayout(child: child),
            routes: [
              GoRoute(
                path: '/list',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  child: ValueListenableBuilder<int>(
                    valueListenable: reading,
                    builder: (context, value, _) => Row(
                      children: [
                        const Expanded(child: Text('Checkout')),
                        SizedBox(width: 64, child: Text('${value}ms')),
                      ],
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/list/detail',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: Text('detail')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        WindTheme(
          data: WindThemeData(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/list/detail');
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);

      for (int i = 1; i <= 3; i++) {
        reading.value = i * 100;
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(tester.takeException(), isNull);
    });
  });
}
