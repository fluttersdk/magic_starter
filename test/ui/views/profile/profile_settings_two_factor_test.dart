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
// Mock Guard — configurable user state for 2FA tests
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Map<String, dynamic>? _userData;
  String? _token = 'mock-token';

  /// Sets a user whose two-factor authentication is disabled.
  void setUserWithTwoFactorDisabled() {
    _userData = <String, dynamic>{
      'id': 1,
      'name': 'Alice',
      'email': 'alice@example.com',
      'email_verified_at': '2025-01-15T10:00:00.000000Z',
      'two_factor_enabled': false,
    };
  }

  /// Sets a user whose two-factor authentication is enabled.
  void setUserWithTwoFactorEnabled() {
    _userData = <String, dynamic>{
      'id': 1,
      'name': 'Alice',
      'email': 'alice@example.com',
      'email_verified_at': '2025-01-15T10:00:00.000000Z',
      'two_factor_enabled': true,
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
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: SingleChildScrollView(child: widget),
        ),
      ),
    );
  }

  group('2FA Section', () {
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

      // 5. Enable two-factor feature flag.
      Config.set('magic_starter.features.two_factor', true);

      // 6. Bind MagicStarterManager.
      Magic.singleton(
        'magic_starter',
        () => MagicStarterManager(),
      );

      // 7. Create and inject controller.
      Magic.put(StarterProfileController());

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
    });

    tearDown(() {
      Auth.manager.forgetGuards();
      Gate.flush();
    });

    testWidgets(
      '2FA section is visible when hasTwoFactorFeatures is true',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pump();

        // The 2FA card title must be rendered when feature is enabled.
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WText &&
                widget.data == trans('profile.two_factor_authentication'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2FA section shows disabled state when two_factor_enabled is false on user',
      (WidgetTester tester) async {
        // User with two_factor_enabled: false — view should initialize
        // to disabled state reading from auth user, showing the
        // disabled description and the Enable button.
        mockGuard.setUserWithTwoFactorDisabled();

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pump();

        // Disabled description must be visible.
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WText &&
                widget.data == trans('profile.two_factor_disabled_description'),
          ),
          findsOneWidget,
        );

        // Enabled status text must NOT be visible in disabled state.
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WText &&
                widget.data == trans('profile.two_factor_enabled'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      '2FA section shows enabled state when two_factor_enabled is true on user',
      (WidgetTester tester) async {
        // User with two_factor_enabled: true — view should initialize
        // to enabled state reading from auth user, showing the enabled
        // status badge and management buttons.
        mockGuard.setUserWithTwoFactorEnabled();

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pump();

        // Green enabled status badge must be visible.
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WText &&
                widget.data == trans('profile.two_factor_enabled'),
          ),
          findsOneWidget,
        );

        // Disabled description must NOT be visible in enabled state.
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WText &&
                widget.data == trans('profile.two_factor_disabled_description'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Enable button is visible in disabled state',
      (WidgetTester tester) async {
        mockGuard.setUserWithTwoFactorDisabled();

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pump();

        // The Enable button must be visible when 2FA is disabled.
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WButton &&
                widget.child is WText &&
                (widget.child as WText).data ==
                    trans('profile.two_factor_enable'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Disable button is visible in enabled state',
      (WidgetTester tester) async {
        // User with 2FA enabled — view should show the Disable button.
        mockGuard.setUserWithTwoFactorEnabled();

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pump();

        // The Disable button must be visible when 2FA is enabled.
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is WButton &&
                widget.child is WText &&
                (widget.child as WText).data ==
                    trans('profile.two_factor_disable'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
