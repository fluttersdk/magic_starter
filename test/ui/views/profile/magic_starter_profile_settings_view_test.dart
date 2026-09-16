import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

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
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => _respond('GET', url);

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
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => _respond('DELETE', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async => _respond('INDEX', resource);

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
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async => _respond('UPLOAD', url, data: data);
}

// ---------------------------------------------------------------------------
// Mock Guard
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool logoutCalled = false;
  bool restoreCalled = false;
  String? mockToken = 'mock-token';

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    mockToken = data['token'] as String?;
    _user = user;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
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
// Test Suite
// ---------------------------------------------------------------------------

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
  }

  group('MagicStarterProfileSettingsView', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      MagicApp.reset();
      Magic.flush();

      // Config defaults
      Config.set('magic_starter.features.extended_profile', true);

      // 1. Bind mock network driver.
      mockDriver = MockNetworkDriver();
      Magic.singleton('network', () => mockDriver);

      // 2. Bind log manager.
      Magic.singleton('log', () => LogManager());

      // 3. Bind auth with mock guard.
      mockGuard = MockGuard();
      Magic.singleton('auth', () => AuthManager());
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {'driver': 'mock'},
      });

      // 4. Set authenticated user.
      mockGuard.setUser(
        MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Test User',
          'email': 'test@example.com',
          'phone': '+905301234567',
          'timezone': 'Europe/Istanbul',
          'language': 'tr',
        }),
      );

      // 5. Bind MagicStarterManager.
      Magic.singleton('magic_starter', () => MagicStarterManager());

      // 6. Create and inject controller.
      Magic.put(MagicStarterProfileController());

      // 7. Register Gate abilities — non-guest user has all abilities.
      Gate.flush();
      Gate.define('starter.update-profile-photo', (user, [_]) => true);
      Gate.define('starter.update-email', (user, [_]) => true);
      Gate.define('starter.update-phone', (user, [_]) => true);
      Gate.define('starter.update-password', (user, [_]) => true);
      Gate.define('starter.verify-email', (user, [_]) => true);
      Gate.define('starter.manage-two-factor', (user, [_]) => true);
      Gate.define('starter.manage-newsletter', (user, [_]) => true);
      Gate.define('starter.logout-sessions', (user, [_]) => true);
      Gate.define('starter.delete-account', (user, [_]) => true);
    });

    tearDown(() {
      Auth.manager.forgetGuards();
      Gate.flush();
    });

    // -----------------------------------------------------------------------
    // Merged profile section tests
    // -----------------------------------------------------------------------

    testWidgets('merged profile section renders all fields in a single card', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));

      // The old separate "extended-profile-section" card must NOT exist.
      expect(find.byKey(const Key('extended-profile-section')), findsNothing);

      // All five fields should be present: name, email, phone (inputs)
      // + timezone, language (selects).
      expect(find.byType(WFormInput), findsWidgets);
      expect(find.byType(WFormSelect<String>), findsOneWidget);
      expect(find.byType(MagicStarterTimezoneSelect), findsOneWidget);
    });

    testWidgets(
      'extended fields hidden when feature disabled but core fields remain',
      (tester) async {
        Config.set('magic_starter.features.extended_profile', false);

        await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));

        // No separate extended section card.
        expect(find.byKey(const Key('extended-profile-section')), findsNothing);

        // Phone field should NOT be rendered.
        expect(find.text('profile.phone_label'), findsNothing);

        // Timezone and language selects should NOT be rendered.
        expect(find.byType(WFormSelect<String>), findsNothing);
        expect(find.byType(MagicStarterTimezoneSelect), findsNothing);

        // Core fields (name, email) should still be present.
        expect(find.text('attributes.name'), findsOneWidget);
        expect(find.text('attributes.email'), findsOneWidget);
      },
    );

    testWidgets(
      'backend validation errors display on form fields after failed submit',
      (tester) async {
        // Mock a 422 validation error for the 'name' field.
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'The given data was invalid.',
            'errors': {
              'name': ['The name field is required.'],
            },
          },
        );

        await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));

        // Scroll to and tap the profile save button.
        final saveButtons = find.widgetWithText(WButton, 'common.save');
        expect(saveButtons, findsWidgets);

        await tester.ensureVisible(saveButtons.first);
        await tester.pumpAndSettle();
        await tester.tap(saveButtons.first);
        await tester.pumpAndSettle();

        // The backend validation error message should now be visible.
        expect(find.text('The name field is required.'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // Slot injection tests
    // -----------------------------------------------------------------------

    group('slot injection', () {
      testWidgets('header slot renders injected widget', (tester) async {
        MagicStarter.view.slot(
          'profile.settings',
          'header',
          (ctx) => const Text('Custom Header'),
        );

        await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));

        expect(find.text('Custom Header'), findsOneWidget);
      });

      testWidgets('footer slot renders injected widget', (tester) async {
        MagicStarter.view.slot(
          'profile.settings',
          'footer',
          (ctx) => const Text('Custom Footer'),
        );

        await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));

        expect(find.text('Custom Footer'), findsOneWidget);
      });
    });

    // -----------------------------------------------------------------------
    // Sessions section
    // -----------------------------------------------------------------------

    testWidgets('a native session is named by its application', (tester) async {
      // This screen kept building the row title from platform and browser
      // alone while the sessions screen moved onto `sessionDeviceTitle`, so a
      // phone still rendered as the page heading beside a mobile icon. Both
      // screens are published, so an adopter who published this one saw the
      // old behaviour after the fix.
      Config.set('magic_starter.features.sessions', true);
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': [
            {
              'id': 7,
              'ip_address': '10.0.0.1',
              'is_current_device': false,
              'agent': {
                'is_desktop': false,
                'platform': 'iOS',
                'browser': '',
                'app': 'Uptizm',
              },
              'location': {'city': 'Istanbul', 'country': 'Turkey'},
            },
          ],
        },
      );

      await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));
      await tester.pumpAndSettle();

      expect(find.text('iOS - Uptizm'), findsOneWidget);
    });

    testWidgets('an unreadable agent falls back to the key, not to nothing', (
      tester,
    ) async {
      // The half that was silently rendering an empty title here, and the half
      // the CHANGELOG calls a live regression on upgrade: an app whose
      // catalogue predates the key sees `profile.unknown_device` rendered as
      // itself, which is loud, where an empty row says nothing at all.
      Config.set('magic_starter.features.sessions', true);
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': [
            {
              'id': 9,
              'ip_address': '10.0.0.2',
              'is_current_device': false,
              'agent': <String, dynamic>{'is_desktop': true},
              'location': <String, dynamic>{},
            },
          ],
        },
      );

      await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));
      await tester.pumpAndSettle();

      expect(find.text('profile.unknown_device'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Theme consumption tests
    // -----------------------------------------------------------------------

    group('theme consumption', () {
      testWidgets('custom FormTheme renders without crash', (tester) async {
        MagicStarter.useFormTheme(
          const MagicStarterFormTheme(
            inputClassName: 'rounded-none border-2 border-blue-500',
            labelClassName: 'text-xs font-bold text-blue-700',
          ),
        );

        await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));

        expect(tester.takeException(), isNull);
      });
    });
  });
}
