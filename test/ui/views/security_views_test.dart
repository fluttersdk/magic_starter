import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/views/settings/security/magic_starter_two_factor_view.dart';
import 'package:magic_starter/src/ui/views/settings/security/magic_starter_password_view.dart';
import 'package:magic_starter/src/ui/views/settings/security/magic_starter_sessions_view.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver — intercepts all Http facade calls. Supports a small
// response queue so multi-request flows (e.g. session load) resolve in order.
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  final List<MagicResponse> _queue = <MagicResponse>[];

  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

  void mockResponse({
    required int statusCode,
    dynamic data,
  }) {
    _queue.add(
      MagicResponse(
        data: data ?? <String, dynamic>{},
        statusCode: statusCode,
      ),
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

    if (_queue.isNotEmpty) {
      return _queue.removeAt(0);
    }

    return MagicResponse(
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
// Mock Guard — configurable authenticated user state for security views.
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Map<String, dynamic>? _userData;
  String? _token = 'mock-token';

  void setUserWithTwoFactorDisabled() {
    _userData = <String, dynamic>{
      'id': 1,
      'name': 'Alice',
      'email': 'alice@example.com',
      'email_verified_at': '2025-01-15T10:00:00.000000Z',
      'two_factor_enabled': false,
    };
  }

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
      builder: (context, child) => WindTheme(
        data: WindThemeData(),
        child: child!,
      ),
      home: Scaffold(body: widget),
    );
  }

  late MockNetworkDriver mockDriver;
  late MockGuard mockGuard;

  void bootMagic() {
    MagicApp.reset();
    Magic.flush();

    mockDriver = MockNetworkDriver();
    Magic.singleton('network', () => mockDriver);

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

    mockGuard = MockGuard();
    Magic.singleton('auth', () => AuthManager());
    Auth.manager.forgetGuards();
    Auth.manager.extend('mock', (_) => mockGuard);
    Config.set('auth.defaults.guard', 'mock');
    Config.set('auth.guards', <String, dynamic>{
      'mock': <String, dynamic>{'driver': 'mock'},
    });
    mockGuard.setUserWithTwoFactorDisabled();

    Config.set('magic_starter.features.two_factor', true);
    Config.set('magic_starter.features.sessions', true);

    Magic.singleton('magic_starter', () => MagicStarterManager());
    Magic.put(MagicStarterProfileController());

    Gate.flush();
    Gate.define('starter.update-password', (user, [_]) => true);
    Gate.define('starter.manage-two-factor', (user, [_]) => true);
    Gate.define('starter.logout-sessions', (user, [_]) => true);
    Gate.define('starter.delete-account', (user, [_]) => true);
  }

  setUp(bootMagic);

  tearDown(() {
    Auth.manager.forgetGuards();
    Gate.flush();
  });

  // -------------------------------------------------------------------------
  // Two-Factor view
  // -------------------------------------------------------------------------

  group('MagicStarterTwoFactorView', () {
    testWidgets('renders inside a SettingsScaffold with back to the hub',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const MagicStarterTwoFactorView()));
      await tester.pump();

      expect(find.byType(SettingsScaffold), findsOneWidget);

      final scaffold = tester.widget<SettingsScaffold>(
        find.byType(SettingsScaffold),
      );
      expect(scaffold.backLabel, isNotNull);
      expect(scaffold.backFallback, MagicStarterConfig.settingsHubRoute());
    });

    testWidgets('shows disabled state with the Enable button',
        (WidgetTester tester) async {
      mockGuard.setUserWithTwoFactorDisabled();

      await tester.pumpWidget(wrap(const MagicStarterTwoFactorView()));
      await tester.pump();

      expect(
        find.byWidgetPredicate((Widget w) =>
            w is WButton &&
            w.child is WText &&
            (w.child as WText).data == trans('profile.two_factor_enable')),
        findsOneWidget,
      );
    });

    testWidgets('shows enabled state with the Disable button',
        (WidgetTester tester) async {
      mockGuard.setUserWithTwoFactorEnabled();

      await tester.pumpWidget(wrap(const MagicStarterTwoFactorView()));
      await tester.pump();

      expect(
        find.byWidgetPredicate((Widget w) =>
            w is WText && w.data == trans('profile.two_factor_enabled')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((Widget w) =>
            w is WButton &&
            w.child is WText &&
            (w.child as WText).data == trans('profile.two_factor_disable')),
        findsOneWidget,
      );
    });

    testWidgets('Disable button opens the password-confirm dialog',
        (WidgetTester tester) async {
      mockGuard.setUserWithTwoFactorEnabled();

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MagicStarterTwoFactorView()));
      await tester.pump();

      final btn = find.byWidgetPredicate((Widget w) =>
          w is WButton &&
          w.child is WText &&
          (w.child as WText).data == trans('profile.two_factor_disable'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterPasswordConfirmDialog), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Password view
  // -------------------------------------------------------------------------

  group('MagicStarterPasswordView', () {
    testWidgets('renders inside a SettingsScaffold with back to the hub',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const MagicStarterPasswordView()));
      await tester.pump();

      expect(find.byType(SettingsScaffold), findsOneWidget);

      final scaffold = tester.widget<SettingsScaffold>(
        find.byType(SettingsScaffold),
      );
      expect(scaffold.backFallback, MagicStarterConfig.settingsHubRoute());
    });

    testWidgets('submitting the form calls PUT /user/password',
        (WidgetTester tester) async {
      mockDriver.mockResponse(statusCode: 200, data: <String, dynamic>{});

      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MagicStarterPasswordView()));
      await tester.pump();

      final inputs = find.byType(WFormInput);
      expect(inputs, findsNWidgets(3));
      await tester.enterText(inputs.at(0), 'current-secret');
      await tester.enterText(inputs.at(1), 'new-secret-123');
      await tester.enterText(inputs.at(2), 'new-secret-123');

      final submit = find.byWidgetPredicate((Widget w) =>
          w is WButton &&
          w.child is WText &&
          (w.child as WText).data == trans('profile.update_password'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(mockDriver.lastMethod, 'PUT');
      expect(mockDriver.lastUrl, contains('/user/password'));
      expect(mockDriver.lastData['current_password'], 'current-secret');
    });
  });

  // -------------------------------------------------------------------------
  // Sessions view
  // -------------------------------------------------------------------------

  group('MagicStarterSessionsView', () {
    testWidgets('renders inside a SettingsScaffold with back to the hub',
        (WidgetTester tester) async {
      mockDriver.mockResponse(statusCode: 200, data: <String, dynamic>{
        'data': <dynamic>[],
      });

      await tester.pumpWidget(wrap(const MagicStarterSessionsView()));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SettingsScaffold), findsOneWidget);

      final scaffold = tester.widget<SettingsScaffold>(
        find.byType(SettingsScaffold),
      );
      expect(scaffold.backFallback, MagicStarterConfig.settingsHubRoute());
    });

    testWidgets('loads sessions via GET /sessions on init',
        (WidgetTester tester) async {
      mockDriver.mockResponse(statusCode: 200, data: <String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{
            'id': '99',
            'is_current_device': false,
            'agent': <String, dynamic>{
              'is_desktop': true,
              'platform': 'macOS',
              'browser': 'Chrome',
            },
            'ip_address': '10.0.0.1',
            'location': <String, dynamic>{},
          },
        ],
      });

      await tester.pumpWidget(wrap(const MagicStarterSessionsView()));
      await tester.pump();
      await tester.pump();

      expect(mockDriver.lastMethod, 'GET');
      expect(mockDriver.lastUrl, contains('/sessions'));

      // A SettingsRow is rendered per device.
      expect(find.byType(SettingsRow), findsWidgets);
    });

    testWidgets(
        'revoke-other-sessions button opens the password-confirm dialog',
        (WidgetTester tester) async {
      mockDriver.mockResponse(statusCode: 200, data: <String, dynamic>{
        'data': <dynamic>[],
      });

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MagicStarterSessionsView()));
      await tester.pump();
      await tester.pump();

      final btn = find.byWidgetPredicate((Widget w) =>
          w is WButton &&
          w.child is WText &&
          (w.child as WText).data == trans('profile.logout_other_sessions'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterPasswordConfirmDialog), findsOneWidget);
    });
  });
}
