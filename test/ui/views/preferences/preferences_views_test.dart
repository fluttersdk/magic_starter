import 'package:flutter/material.dart' hide Switch;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
// The preference sub-page views are registered via the view registry
// (keys `settings.appearance` / `settings.language` / `settings.timezone` /
// `settings.newsletter`) and wired into routing/registry in Step 11; import
// them directly here for the test.
import 'package:magic_starter/src/ui/views/settings/preferences/magic_starter_appearance_view.dart';
import 'package:magic_starter/src/ui/views/settings/preferences/magic_starter_language_view.dart';
import 'package:magic_starter/src/ui/views/settings/preferences/magic_starter_timezone_view.dart';
import 'package:magic_starter/src/ui/views/settings/preferences/magic_starter_newsletter_view.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;
  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(data: data ?? {}, statusCode: statusCode);
  }

  MagicResponse _respond(String method, String url, {dynamic data}) {
    lastMethod = method;
    lastUrl = url;
    lastData = data;
    return nextResponse ?? MagicResponse(data: {}, statusCode: 500);
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> get(String url,
          {Map<String, dynamic>? query, Map<String, String>? headers}) async =>
      _respond('GET', url);

  @override
  Future<MagicResponse> post(String url,
          {dynamic data, Map<String, String>? headers}) async =>
      _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(String url,
          {dynamic data, Map<String, String>? headers}) async =>
      _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> delete(String url,
          {Map<String, String>? headers}) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> index(String resource,
          {Map<String, dynamic>? filters,
          Map<String, String>? headers}) async =>
      _respond('INDEX', resource);

  @override
  Future<MagicResponse> show(String resource, String id,
          {Map<String, String>? headers}) async =>
      _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(String resource, Map<String, dynamic> data,
          {Map<String, String>? headers}) async =>
      _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
          String resource, String id, Map<String, dynamic> data,
          {Map<String, String>? headers}) async =>
      _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> destroy(String resource, String id,
          {Map<String, String>? headers}) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(String url,
          {required Map<String, dynamic> data,
          required Map<String, dynamic> files,
          Map<String, String>? headers}) async =>
      _respond('UPLOAD', url, data: data);
}

// ---------------------------------------------------------------------------
// Mock Guard
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool restoreCalled = false;
  String? mockToken = 'mock-token';

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    mockToken = data['token'] as String?;
    _user = user;
  }

  @override
  Future<void> logout() async {
    _user = null;
    mockToken = null;
  }

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  T? user<T extends Model>() => _user as T?;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  void setUser(Authenticatable user) => _user = user;

  @override
  Future<bool> hasToken() async => mockToken != null;

  @override
  Future<String?> getToken() async => mockToken;

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {
    restoreCalled = true;
    if (mockToken != null) {
      _user = MagicStarterAuthUser.fromMap({'id': 1, 'name': 'Restored User'});
    }
  }

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

void main() {
  late MockNetworkDriver mockDriver;
  late MockGuard mockGuard;

  // Wraps the view in a WindTheme so the appearance controller can resolve a
  // WindThemeController, exposing the live controller via [onController].
  Widget wrap(
    Widget widget, {
    WindThemeData? themeData,
    void Function(WindThemeController controller)? onController,
  }) {
    return WindTheme(
      data: themeData ?? WindThemeData(),
      builder: (context, controller) {
        onController?.call(controller);
        return MaterialApp(
          home: Scaffold(body: widget),
        );
      },
    );
  }

  void bootMagic() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MagicApp.reset();
    Magic.flush();

    Config.set('magic_starter.features.extended_profile', true);
    Config.set('magic_starter.features.timezones', true);
    Config.set('magic_starter.features.newsletter', true);

    mockDriver = MockNetworkDriver();
    Magic.singleton('network', () => mockDriver);
    Magic.singleton('log', () => LogManager());

    mockGuard = MockGuard();
    Magic.singleton('auth', () => AuthManager());
    Auth.manager.forgetGuards();
    Auth.manager.extend('mock', (_) => mockGuard);
    Config.set('auth.defaults.guard', 'mock');
    Config.set('auth.guards', {
      'mock': {
        'driver': 'mock',
      },
    });

    mockGuard.setUser(
      MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Test User',
        'email': 'test@example.com',
        'timezone': 'Europe/Istanbul',
        // The profile views read the locale field via `user.get('locale')`.
        'locale': 'tr',
      }),
    );

    Magic.singleton('magic_starter', () => MagicStarterManager());
    Magic.put(MagicStarterProfileController());
    Magic.put(MagicStarterNewsletterController());

    Gate.flush();
    Gate.define('starter.update-email', (user, [_]) => true);
    Gate.define('starter.manage-newsletter', (user, [_]) => true);
  }

  setUp(bootMagic);

  tearDown(() {
    Auth.manager.forgetGuards();
    Gate.flush();
  });

  // -------------------------------------------------------------------------
  // Appearance
  // -------------------------------------------------------------------------

  group('MagicStarterAppearanceView', () {
    testWidgets('renders inside a SettingsScaffold with a back to the hub',
        (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterAppearanceView()));
      await tester.pumpAndSettle();

      expect(find.byType(MSPageScaffold), findsOneWidget);
      final scaffold =
          tester.widget<MSPageScaffold>(find.byType(MSPageScaffold));
      expect(scaffold.backLabel, isNotNull);
      expect(scaffold.backFallback, MagicStarterConfig.settingsHubRoute());
    });

    testWidgets('renders three appearance option rows', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterAppearanceView()));
      await tester.pumpAndSettle();

      // Light / Dark / System option cards.
      final rows = tester.widgetList<MSSettingsRow>(find.byType(MSSettingsRow));
      expect(rows.length, greaterThanOrEqualTo(3));
    });

    testWidgets('selecting the Dark option switches the theme to dark',
        (tester) async {
      WindThemeController? controller;
      await tester.pumpWidget(
        wrap(
          const MagicStarterAppearanceView(),
          themeData: WindThemeData(brightness: Brightness.light),
          onController: (c) => controller = c,
        ),
      );
      await tester.pumpAndSettle();

      expect(controller!.brightness, Brightness.light);

      final darkRow = find.widgetWithText(
        MSSettingsRow,
        'magic_starter.appearance.dark',
      );
      expect(darkRow, findsOneWidget);
      await tester.ensureVisible(darkRow);
      await tester.tap(darkRow);
      await tester.pumpAndSettle();

      expect(controller!.brightness, Brightness.dark);
      // Manual preference disables system sync (persistence path).
      expect(controller!.data.syncWithSystem, isFalse);
    });

    testWidgets('selecting the Light option switches the theme to light',
        (tester) async {
      WindThemeController? controller;
      await tester.pumpWidget(
        wrap(
          const MagicStarterAppearanceView(),
          // syncWithSystem:false so the initial dark brightness is preserved
          // (a true syncWithSystem theme is forced to the test platform
          // brightness on startup).
          themeData: WindThemeData(
            brightness: Brightness.dark,
            syncWithSystem: false,
          ),
          onController: (c) => controller = c,
        ),
      );
      await tester.pumpAndSettle();

      expect(controller!.brightness, Brightness.dark);

      final lightRow = find.widgetWithText(
        MSSettingsRow,
        'magic_starter.appearance.light',
      );
      expect(lightRow, findsOneWidget);
      await tester.ensureVisible(lightRow);
      await tester.tap(lightRow);
      await tester.pumpAndSettle();

      expect(controller!.brightness, Brightness.light);
      expect(controller!.data.syncWithSystem, isFalse);
    });

    testWidgets('selecting the System option re-enables system sync',
        (tester) async {
      WindThemeController? controller;
      await tester.pumpWidget(
        wrap(
          const MagicStarterAppearanceView(),
          themeData: WindThemeData(
            brightness: Brightness.dark,
            syncWithSystem: false,
          ),
          onController: (c) => controller = c,
        ),
      );
      await tester.pumpAndSettle();

      expect(controller!.data.syncWithSystem, isFalse);

      final systemRow = find.widgetWithText(
        MSSettingsRow,
        'magic_starter.appearance.system',
      );
      expect(systemRow, findsOneWidget);
      await tester.ensureVisible(systemRow);
      await tester.tap(systemRow);
      await tester.pumpAndSettle();

      expect(controller!.data.syncWithSystem, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Language
  // -------------------------------------------------------------------------

  group('MagicStarterLanguageView', () {
    testWidgets('renders inside a SettingsScaffold with a back to the hub',
        (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterLanguageView()));
      await tester.pumpAndSettle();

      expect(find.byType(MSPageScaffold), findsOneWidget);
      final scaffold =
          tester.widget<MSPageScaffold>(find.byType(MSPageScaffold));
      expect(scaffold.backFallback, MagicStarterConfig.settingsHubRoute());
    });

    testWidgets('renders a locale select', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterLanguageView()));
      await tester.pumpAndSettle();

      expect(find.byType(WFormSelect<String>), findsOneWidget);
    });

    testWidgets('saving the language submits the locale to /user/profile',
        (tester) async {
      mockDriver.mockResponse(statusCode: 200, data: {'data': {}});

      await tester.pumpWidget(wrap(const MagicStarterLanguageView()));
      await tester.pumpAndSettle();

      final saveButton = find.byType(WButton);
      expect(saveButton, findsWidgets);
      await tester.ensureVisible(saveButton.first);
      await tester.tap(saveButton.first);
      await tester.pumpAndSettle();

      expect(mockDriver.lastMethod, 'PUT');
      expect(mockDriver.lastUrl, contains('/user/profile'));
      expect((mockDriver.lastData as Map)['locale'], 'tr');
    });
  });

  // -------------------------------------------------------------------------
  // Timezone
  // -------------------------------------------------------------------------

  group('MagicStarterTimezoneView', () {
    testWidgets('renders inside a SettingsScaffold with a back to the hub',
        (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterTimezoneView()));
      await tester.pumpAndSettle();

      expect(find.byType(MSPageScaffold), findsOneWidget);
      final scaffold =
          tester.widget<MSPageScaffold>(find.byType(MSPageScaffold));
      expect(scaffold.backFallback, MagicStarterConfig.settingsHubRoute());
    });

    testWidgets('renders the debounced timezone select', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterTimezoneView()));
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterTimezoneSelect), findsOneWidget);
    });

    testWidgets('saving the timezone submits to /user/profile', (tester) async {
      mockDriver.mockResponse(statusCode: 200, data: {'data': {}});

      await tester.pumpWidget(wrap(const MagicStarterTimezoneView()));
      await tester.pumpAndSettle();

      final saveButton = find.byType(WButton);
      expect(saveButton, findsWidgets);
      await tester.ensureVisible(saveButton.first);
      await tester.tap(saveButton.first);
      await tester.pumpAndSettle();

      expect(mockDriver.lastMethod, 'PUT');
      expect(mockDriver.lastUrl, contains('/user/profile'));
      expect((mockDriver.lastData as Map)['timezone'], 'Europe/Istanbul');
    });
  });

  // -------------------------------------------------------------------------
  // Newsletter
  // -------------------------------------------------------------------------

  group('MagicStarterNewsletterView', () {
    testWidgets('renders inside a SettingsScaffold with a back to the hub',
        (tester) async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': {'subscribed': false},
        },
      );

      await tester.pumpWidget(wrap(const MagicStarterNewsletterView()));
      await tester.pumpAndSettle();

      expect(find.byType(MSPageScaffold), findsOneWidget);
      final scaffold =
          tester.widget<MSPageScaffold>(find.byType(MSPageScaffold));
      expect(scaffold.backFallback, MagicStarterConfig.settingsHubRoute());
    });

    testWidgets('renders a SettingsRow with a trailing Switch', (tester) async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': {'subscribed': false},
        },
      );

      await tester.pumpWidget(wrap(const MagicStarterNewsletterView()));
      await tester.pumpAndSettle();

      expect(find.byType(MSSettingsRow), findsWidgets);
      expect(find.byType(MSSwitch), findsOneWidget);
    });

    testWidgets('toggling the switch updates the subscription via PUT',
        (tester) async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': {'subscribed': false},
        },
      );

      await tester.pumpWidget(wrap(const MagicStarterNewsletterView()));
      await tester.pumpAndSettle();

      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': {'subscribed': true},
        },
      );

      final toggle = find.byType(MSSwitch);
      expect(toggle, findsOneWidget);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(mockDriver.lastMethod, 'PUT');
      expect(mockDriver.lastUrl, contains('/user/newsletter'));
      expect((mockDriver.lastData as Map)['subscribe'], true);
    });
  });
}
