import 'package:flutter/foundation.dart';
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
    dynamic data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
      _respond('UPLOAD', url, data: data);

  @override
  bool get hasInterceptors => false;
}

// ---------------------------------------------------------------------------
// Mock Guard — configurable user state for verification tests
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Map<String, dynamic>? _userData;
  String? _token = 'mock-token';

  void setVerifiedUser() {
    _userData = {
      'id': 1,
      'name': 'Alice',
      'email': 'alice@example.com',
      'email_verified_at': '2025-01-15T10:00:00.000000Z',
    };
  }

  void setUnverifiedUser() {
    _userData = {
      'id': 1,
      'name': 'Alice',
      'email': 'alice@example.com',
      'email_verified_at': null,
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
        child: Scaffold(
          body: SingleChildScrollView(child: widget),
        ),
      ),
    );
  }

  group('MagicStarterProfileSettingsView — email verification section', () {
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
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      // 3. Bind auth with mock guard.
      mockGuard = MockGuard();
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {'driver': 'mock'},
      });

      // 4. Set authenticated user with no email_verified_at.
      mockGuard.setUnverifiedUser();

      // 5. Enable email verification feature.
      Config.set('magic_starter.features.email_verification', true);

      // 6. Bind MagicStarterManager.
      Magic.singleton(
        'magic_starter',
        () => MagicStarterManager(),
      );

      // 7. Create and inject controller.
      Magic.put(StarterProfileController());
    });

    tearDown(() {
      Auth.manager.forgetGuards();
    });

    testWidgets(
      'banner is hidden when feature is disabled',
      (tester) async {
        Config.set('magic_starter.features.email_verification', false);

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pump();

        // The unverified banner text should NOT be visible.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is WText &&
                widget.data ==
                    trans('magic_starter.email_verification.unverified_title'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'unverified banner renders when email_verified_at is null',
      (tester) async {
        mockGuard.setUnverifiedUser();

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pump();

        // Unverified title should be visible.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is WText &&
                widget.data ==
                    trans('magic_starter.email_verification.unverified_title'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unverified banner shows resend button',
      (tester) async {
        mockGuard.setUnverifiedUser();

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is WButton &&
                widget.child is WText &&
                (widget.child as WText).data ==
                    trans('magic_starter.email_verification.resend_button'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'verified badge renders when email_verified_at has a value',
      (tester) async {
        mockGuard.setVerifiedUser();

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is WText &&
                widget.data ==
                    trans('magic_starter.email_verification.verified'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping resend button calls POST /email/verification-notification',
      (tester) async {
        mockGuard.setUnverifiedUser();
        mockDriver.mockResponse(statusCode: 202, data: {});

        await tester.pumpWidget(
          wrap(const MagicStarterProfileSettingsView()),
        );
        await tester.pump();

        final resendButton = find.byWidgetPredicate(
          (widget) =>
              widget is WButton &&
              widget.child is WText &&
              (widget.child as WText).data ==
                  trans('magic_starter.email_verification.resend_button'),
        );

        expect(resendButton, findsOneWidget);
        await tester.ensureVisible(resendButton);
        await tester.pumpAndSettle();
        await tester.tap(resendButton);
        await tester.pumpAndSettle();

        expect(mockDriver.lastMethod, equals('POST'));
        expect(mockDriver.lastUrl, equals('/email/verification-notification'));
      },
    );
  });
}
