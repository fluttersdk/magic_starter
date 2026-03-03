import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver — intercepts all Http facade calls
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;

  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

  void mockResponse({
    required int statusCode,
    dynamic data,
  }) {
    nextResponse = MagicResponse(
      data: data ?? <String, dynamic>{},
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
    lastData = data;

    return nextResponse ??
        MagicResponse(
          data: <String, dynamic>{},
          statusCode: 500,
        );
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async =>
      _respond('GET', url);

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
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _respond('INDEX', resource);

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
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
      _respond('UPLOAD', url, data: data);
}

// ---------------------------------------------------------------------------
// Mock Guard — configurable user state for newsletter tests
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Map<String, dynamic>? _userData;
  String? _token = 'mock-token';

  /// Sets a user whose two-factor authentication is disabled (default state).
  void setUserWithTwoFactorDisabled() {
    _userData = <String, dynamic>{
      'id': 1,
      'name': 'Alice',
      'email': 'alice@example.com',
      'email_verified_at': '2025-01-15T10:00:00.000000Z',
      'two_factor_enabled': false,
    };
  }

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    _token = data['token'] as String?;
  }

  @override
  Future<void> logout() async {
    _userData = null;
    _token = null;
  }

  @override
  bool check() => _userData != null;

  @override
  bool get guest => !check();

  @override
  T? user<T extends Model>() {
    if (_userData == null) return null;

    return MagicStarterAuthUser.fromMap(_userData!) as T?;
  }

  @override
  dynamic id() => _userData?['id'];

  @override
  void setUser(Authenticatable user) {}

  @override
  Future<bool> hasToken() async => _token != null;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {}

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier<int>(0);
}

// ---------------------------------------------------------------------------
// Test Suite
// ---------------------------------------------------------------------------

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      builder: (context, child) => WindTheme(
        data: WindThemeData(),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(child: widget),
      ),
    );
  }

  group('Newsletter Section', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      // 1. Bind mock network driver.
      mockDriver = MockNetworkDriver();
      Magic.singleton('network', () => mockDriver);

      // 2. Bind log manager.
      Magic.singleton('log', () => LogManager());
      Config.set('logging', <String, dynamic>{
        'default': 'console',
        'channels': <String, dynamic>{
          'console': <String, dynamic>{
            'driver': 'console',
            'level': 'debug',
          },
        },
      });

      // 3. Bind auth with mock guard.
      mockGuard = MockGuard();
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', <String, dynamic>{
        'mock': <String, dynamic>{'driver': 'mock'},
      });

      // 4. Set authenticated user with 2FA disabled by default.
      mockGuard.setUserWithTwoFactorDisabled();

      // 5. Enable newsletter feature flag.
      Config.set('magic_starter.features.newsletter', true);

      // 6. Bind MagicStarterManager.
      Magic.singleton(
        'magic_starter',
        () => MagicStarterManager(),
      );

      // 7. Create and inject controller.
      Magic.put(MagicStarterProfileController());

      // 8. Register Gate abilities.
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

      // 9. Queue default GET /user/newsletter response so onInit() succeeds.
      mockDriver.mockResponse(
        statusCode: 200,
        data: <String, dynamic>{'subscribed': false},
      );
    });

    tearDown(() {
      Auth.manager.forgetGuards();
      Gate.flush();
    });

    testWidgets(
      'newsletter section is visible when hasNewsletterFeatures is true',
      (WidgetTester tester) async {
        // Feature flag is already enabled in setUp — section must render.
        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WText &&
                widget.data == trans('magic_starter.newsletter.section_title'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'newsletter section is hidden when hasNewsletterFeatures is false',
      (WidgetTester tester) async {
        // Override feature flag — section must not be rendered.
        Config.set('magic_starter.features.newsletter', false);

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WText &&
                widget.data == trans('magic_starter.newsletter.section_title'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'switch shows OFF when API returns subscribed false',
      (WidgetTester tester) async {
        // Default mock from setUp already returns subscribed: false.
        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pumpAndSettle();

        // Switch must reflect the unsubscribed state.
        expect(
          find.byWidgetPredicate(
            (Widget widget) => widget is Switch && widget.value == false,
          ),
          findsOneWidget,
        );

        // Unsubscribed status label must be visible.
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WText &&
                widget.data ==
                    trans('magic_starter.newsletter.unsubscribed_status'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'switch shows ON when API returns subscribed true',
      (WidgetTester tester) async {
        // Override mock to return subscribed: true before pumping.
        mockDriver.mockResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'subscribed': true,
            'source': 'register',
            'subscribed_at': '2025-01-01',
          },
        );

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pumpAndSettle();

        // Switch must reflect the subscribed state.
        expect(
          find.byWidgetPredicate(
            (Widget widget) => widget is Switch && widget.value == true,
          ),
          findsOneWidget,
        );

        // Subscribed status label must be visible.
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WText &&
                widget.data ==
                    trans('magic_starter.newsletter.subscribed_status'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'toggling switch calls PUT /user/newsletter with subscribe true',
      (WidgetTester tester) async {
        // Default mock starts with subscribed: false.
        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pumpAndSettle();

        // Queue PUT response before tapping the switch.
        mockDriver.mockResponse(
          statusCode: 200,
          data: <String, dynamic>{'subscribed': true},
        );

        final switchFinder = find.byWidgetPredicate(
          (Widget widget) => widget is Switch && widget.value == false,
        );
        await tester.ensureVisible(switchFinder);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(mockDriver.lastMethod, 'PUT');
        expect(mockDriver.lastUrl, '/user/newsletter');
        expect(mockDriver.lastData?['subscribe'], isTrue);
      },
    );

    testWidgets(
      'toggling switch calls PUT with subscribe false when currently subscribed',
      (WidgetTester tester) async {
        // Start with subscribed: true.
        mockDriver.mockResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'subscribed': true,
            'source': 'register',
            'subscribed_at': '2025-01-01',
          },
        );

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pumpAndSettle();

        // Queue PUT response before tapping the switch.
        mockDriver.mockResponse(
          statusCode: 200,
          data: <String, dynamic>{'subscribed': false},
        );

        final switchFinder = find.byWidgetPredicate(
          (Widget widget) => widget is Switch && widget.value == true,
        );
        await tester.ensureVisible(switchFinder);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(mockDriver.lastData?['subscribe'], isFalse);
      },
    );
  });
}
