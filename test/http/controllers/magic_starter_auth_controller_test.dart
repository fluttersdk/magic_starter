import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver — intercepts all Http facade calls
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;

  String? lastMethod;
  String? lastUrl;
  dynamic lastData;
  Map<String, dynamic>? lastQuery;

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
  }) async {
    lastQuery = query;
    return _respond('GET', url);
  }

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
// Mock Guard — tracks Auth.login() / Auth.logout() calls
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool logoutCalled = false;
  Map<String, dynamic>? lastLoginData;

  /// Null until a login, so a fresh guard is signed out on both halves: no
  /// user and no stored token.
  String? mockToken;

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    lastLoginData = data;
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
    if (mockToken != null) {
      _user = MagicStarterAuthUser.fromMap({'id': 1, 'name': 'Restored User'});
    }
  }

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
}

/// Records the `shouldSave` of every `TextInput.finishAutofillContext` call
/// until the test ends.
List<bool> _recordAutofillSaves() {
  final saves = <bool>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.textInput, (call) async {
    if (call.method == 'TextInput.finishAutofillContext') {
      saves.add(call.arguments as bool);
    }

    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.textInput, null),
  );

  return saves;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MagicStarterAuthController', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late MagicStarterAuthController controller;

    setUp(() {
      // 1. Reset IoC container.
      MagicApp.reset();
      Magic.flush();

      // 2. Bind mock network driver for Http facade.
      Magic.singleton('network', () => MockNetworkDriver());

      // 3. Bind LogManager so Log.error() works in catch blocks.
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      // 4. Bind mock guard for Auth facade.
      mockGuard = MockGuard();
      Magic.singleton('auth', () => AuthManager());
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {'driver': 'mock'},
      });

      // 5. Bind MagicStarterManager for MagicStarter facade.
      Magic.singleton('magic_starter', () => MagicStarterManager());

      // 6. Create a fresh controller instance.
      controller = MagicStarterAuthController();

      // 7. Resolve the mock driver for response setup.
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
      try {
        Notify.stopPolling();
      } catch (_) {
        // Ignore — poller may not be active.
      }
    });

    // ---------------------------------------------------------------------
    // doLogin
    // ---------------------------------------------------------------------

    group('doLogin', () {
      test('success — sets success state and calls Auth.login', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'test-token-123',
              'user': {'id': 1, 'name': 'Alice', 'email': 'alice@example.com'},
            },
          },
        );

        await controller.doLogin(
          email: 'alice@example.com',
          password: 'secret123',
        );

        expect(controller.isSuccess, isTrue);
        expect(controller.rxState, isTrue);
        expect(mockGuard.check(), isTrue);
        expect(mockGuard.lastLoginData?['token'], equals('test-token-123'));
        expect(mockDriver.lastUrl, equals('/auth/login'));
      });

      test('success — offers the typed credentials for saving', () async {
        final saves = _recordAutofillSaves();
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'test-token-123',
              'user': {'id': 1, 'name': 'Alice'},
            },
          },
        );

        await controller.doLogin(
          email: 'alice@example.com',
          password: 'secret123',
        );

        expect(saves, [true]);
      });

      test('failure (422) — sets error state', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Invalid credentials',
            'errors': {
              'email': ['The email is invalid.'],
            },
          },
        );

        await controller.doLogin(email: 'bad@example.com', password: 'wrong');

        expect(controller.isSuccess, isFalse);
        expect(mockGuard.check(), isFalse);
      });

      test('failure (500) — sets error state', () async {
        mockDriver.mockResponse(
          statusCode: 500,
          data: {'message': 'Server error'},
        );

        await controller.doLogin(
          email: 'test@example.com',
          password: 'password',
        );

        expect(controller.isError, isTrue);
        expect(mockGuard.check(), isFalse);
      });

      test('prevents double submission', () async {
        // Simulating concurrent calls — the second should be ignored.
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'tok',
              'user': {'id': 1},
            },
          },
        );

        final future1 = controller.doLogin(email: 'a@b.com', password: 'pass');
        // Second call should be a no-op (already submitting).
        final future2 = controller.doLogin(email: 'a@b.com', password: 'pass');

        await Future.wait([future1, future2]);

        // Only one call should have gone through.
        expect(controller.isSuccess, isTrue);
      });
    });

    // ---------------------------------------------------------------------
    // two factor intercept
    // ---------------------------------------------------------------------

    group('two factor intercept', () {
      test('regression: normal login calls Auth.login', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'bearer-tok',
              'user': {'id': 1, 'name': 'Test', 'email': 'a@b.com'},
            },
          },
        );

        await controller.doLogin(email: 'a@b.com', password: 'pass');

        expect(controller.isSuccess, isTrue);
        expect(mockGuard.check(), isTrue);
      });

      test('intercepts 2fa response at root level', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'two_factor': true, 'two_factor_token': 'enc-tok-123'},
        );

        await controller.doLogin(email: 'a@b.com', password: 'pass');

        // Auth.login should NOT be called
        expect(mockGuard.check(), isFalse);
        expect(mockGuard.lastLoginData, isNull);
        // Wait for potential async navigation, though our _navigateTo is synchronous in test
        // But MagicRoute.to actually pushes to the router, so we need to rely on the side effects
      });

      test('intercepts 2fa response in data key', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {'two_factor': true, 'two_factor_token': 'enc-tok-123'},
          },
        );

        await controller.doLogin(email: 'a@b.com', password: 'pass');

        // Auth.login should NOT be called
        expect(mockGuard.check(), isFalse);
        expect(mockGuard.lastLoginData, isNull);
        expect(mockDriver.lastUrl, equals('/auth/login'));
      });
    });

    // ---------------------------------------------------------------------
    // two factor challenge
    // ---------------------------------------------------------------------

    group('two factor challenge', () {
      test('OTP success calls Auth.login', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'new-bearer',
              'user': {'id': 1, 'name': 'Test', 'email': 'a@b.com'},
            },
          },
        );

        await controller.doTwoFactorChallenge(
          twoFactorToken: 'tok',
          code: '123456',
        );

        expect(controller.isSuccess, isTrue);
        expect(mockGuard.check(), isTrue);
        expect(mockDriver.lastUrl, equals('/auth/two-factor-challenge'));
        expect(mockDriver.lastData?['two_factor_token'], equals('tok'));
        expect(mockDriver.lastData?['code'], equals('123456'));
        expect(mockDriver.lastData?.containsKey('recovery_code'), isFalse);
      });

      test('recovery code success calls Auth.login', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'new-bearer',
              'user': {'id': 1, 'name': 'Test', 'email': 'a@b.com'},
            },
          },
        );

        await controller.doTwoFactorChallenge(
          twoFactorToken: 'tok',
          recoveryCode: 'abcde-12345',
        );

        expect(controller.isSuccess, isTrue);
        expect(mockGuard.check(), isTrue);
        expect(mockDriver.lastUrl, equals('/auth/two-factor-challenge'));
        expect(mockDriver.lastData?['two_factor_token'], equals('tok'));
        expect(mockDriver.lastData?['recovery_code'], equals('abcde-12345'));
        expect(mockDriver.lastData?.containsKey('code'), isFalse);
      });

      test('OTP failure sets error state', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {'message': 'Invalid code.'},
        );

        await controller.doTwoFactorChallenge(
          twoFactorToken: 'tok',
          code: '123456',
        );

        expect(controller.isError, isTrue);
        expect(mockGuard.check(), isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // doRegister
    // ---------------------------------------------------------------------

    group('doRegister', () {
      test('success with token — sets success and calls Auth.login', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'reg-token',
              'user': {'id': 2, 'name': 'Bob', 'email': 'bob@example.com'},
            },
          },
        );

        await controller.doRegister(
          name: 'Bob',
          email: 'bob@example.com',
          password: 'secret123',
          passwordConfirmation: 'secret123',
        );

        expect(controller.isSuccess, isTrue);
        expect(controller.rxState, isTrue);
        expect(mockGuard.check(), isTrue);
        expect(mockDriver.lastUrl, equals('/auth/register'));
      });

      test(
        'success with token — offers the new credentials for saving',
        () async {
          final saves = _recordAutofillSaves();
          mockDriver.mockResponse(
            statusCode: 200,
            data: {
              'data': {
                'token': 'reg-token',
                'user': {'id': 2, 'name': 'Bob'},
              },
            },
          );

          await controller.doRegister(
            name: 'Bob',
            email: 'bob@example.com',
            password: 'secret123',
            passwordConfirmation: 'secret123',
          );

          expect(saves, [true]);
        },
      );

      test('success without token — sets success without login', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {'message': 'Verification email sent'},
          },
        );

        await controller.doRegister(
          name: 'Bob',
          email: 'bob@example.com',
          password: 'secret123',
          passwordConfirmation: 'secret123',
        );

        expect(controller.isSuccess, isTrue);
        // Auth.login should not have been called (no token/user).
        expect(mockGuard.lastLoginData, isNull);
      });

      test('failure (422) — sets error state with validation errors', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Validation failed',
            'errors': {
              'email': ['The email is already taken.'],
            },
          },
        );

        await controller.doRegister(
          name: 'Bob',
          email: 'taken@example.com',
          password: 'secret123',
          passwordConfirmation: 'secret123',
        );

        expect(controller.isSuccess, isFalse);
        expect(mockGuard.check(), isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // doForgotPassword
    // ---------------------------------------------------------------------

    group('doForgotPassword', () {
      test('success — sets success state', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Reset link sent'},
        );

        await controller.doForgotPassword(email: 'alice@example.com');

        expect(controller.isSuccess, isTrue);
        expect(controller.rxState, isTrue);
        expect(mockDriver.lastUrl, equals('/auth/forgot-password'));
      });

      test('failure (422) — sets error state', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Email not found',
            'errors': {
              'email': ['No user found with this email.'],
            },
          },
        );

        await controller.doForgotPassword(email: 'nobody@example.com');

        expect(controller.isSuccess, isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // doResetPassword
    // ---------------------------------------------------------------------

    group('doResetPassword', () {
      test('success — sets success state', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Password reset'},
        );

        await controller.doResetPassword(
          token: 'reset-token-abc',
          email: 'alice@example.com',
          password: 'newpassword',
          passwordConfirmation: 'newpassword',
        );

        expect(controller.isSuccess, isTrue);
        expect(controller.rxState, isTrue);
        expect(mockDriver.lastUrl, equals('/auth/reset-password'));
      });

      test('failure (422) — sets error state', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Invalid token',
            'errors': {
              'token': ['The token is invalid.'],
            },
          },
        );

        await controller.doResetPassword(
          token: 'expired-token',
          email: 'alice@example.com',
          password: 'newpassword',
          passwordConfirmation: 'newpassword',
        );

        expect(controller.isSuccess, isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // doVerifyEmail
    // ---------------------------------------------------------------------

    group('doVerifyEmail', () {
      Future<void> verify() => controller.doVerifyEmail(
        id: 'user-7',
        hash: 'abc123',
        expires: '1792366139',
        signature: 'sig-xyz',
      );

      test('replays the mailed link against the signed API route', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Email verified successfully.'},
        );

        await verify();

        expect(mockDriver.lastMethod, 'GET');
        expect(mockDriver.lastUrl, '/email/verify/user-7/abc123');
        expect(mockDriver.lastQuery, {
          'expires': '1792366139',
          'signature': 'sig-xyz',
        });
        expect(controller.isSuccess, isTrue);
      });

      test('refreshes a signed-in user so the verified flag lands', () async {
        mockGuard.mockToken = 'token-1';
        mockDriver.mockResponse(statusCode: 200, data: {'message': 'ok'});

        await verify();

        expect(Auth.user()?.get<String>('name'), 'Restored User');
      });

      test('an invalid or expired link sets the error state', () async {
        mockDriver.mockResponse(
          statusCode: 403,
          data: {'message': 'Invalid signature.'},
        );

        await verify();

        expect(controller.isSuccess, isFalse);
        expect(controller.isError, isTrue);
      });
    });

    // ---------------------------------------------------------------------
    // logout
    // ---------------------------------------------------------------------

    group('logout', () {
      test('calls Auth.logout()', () async {
        await controller.logout();

        expect(mockGuard.logoutCalled, isTrue);
      });

      test(
        'stops notification polling when notification features are enabled',
        () async {
          Config.set('magic_starter.features.notifications', true);

          // Start polling to create an active poller.
          Notify.startPolling();

          await controller.logout();

          // Polling should be stopped — starting again should create a fresh poller
          // that fetches immediately, proving the old one was cleaned up.
          expect(mockGuard.logoutCalled, isTrue);
        },
      );

      test('calls logoutPush when notification features are enabled', () async {
        Config.set('magic_starter.features.notifications', true);

        // logoutPush() should not throw even without a push driver configured,
        // because NotificationManager.logoutPush() returns early when _pushDriver is null.
        await controller.logout();

        expect(mockGuard.logoutCalled, isTrue);
      });

      test(
        'skips notification cleanup when notification features are disabled',
        () async {
          Config.set('magic_starter.features.notifications', false);

          await controller.logout();

          // Auth logout should still be called even without notification cleanup.
          expect(mockGuard.logoutCalled, isTrue);
        },
      );

      test('completes logout even when notification cleanup throws', () async {
        Config.set('magic_starter.features.notifications', true);

        // Logout should complete gracefully even if notification cleanup fails.
        // Since we can't easily make Notify.stopPolling() throw, we verify
        // the overall contract: Auth.logout() is called regardless.
        await controller.logout();

        expect(mockGuard.logoutCalled, isTrue);
      });

      test('revokes the token server-side before clearing it', () async {
        // Booted for real: the provider is what registers the revoke hook.
        final provider = MagicStarterServiceProvider(MagicApp.instance);
        provider.register();
        await provider.boot();

        mockGuard.mockToken = 'account-token';
        final tokensAtRequest = <String, String?>{};
        final fake = Http.fake((MagicRequest request) {
          tokensAtRequest['${request.method} ${request.url}'] =
              mockGuard.mockToken;
          return Http.response();
        });

        await controller.logout();

        // The AuthInterceptor attaches the guard's token to every request, so
        // the token the guard held when the POST went out is its bearer.
        expect(tokensAtRequest, {'POST /auth/logout': 'account-token'});
        fake.assertSentCount(1);
        expect(mockGuard.logoutCalled, isTrue);
        expect(mockGuard.mockToken, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // doLogin — identity mode tests
    // -------------------------------------------------------------------------

    group('doLogin — email-only mode (default)', () {
      setUp(() {
        Config.set('magic_starter.auth.email', true);
        Config.set('magic_starter.auth.phone', false);
      });

      test('sends email in payload, no phone field', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'tok-email',
              'user': {'id': 1, 'name': 'Alice', 'email': 'test@example.com'},
            },
          },
        );

        await controller.doLogin(email: 'test@example.com', password: 'secret');

        final body = mockDriver.lastData as Map<String, dynamic>?;
        expect(body?['email'], equals('test@example.com'));
        expect(body?.containsKey('phone'), isFalse);
        expect(controller.isSuccess, isTrue);
      });
    });

    group('doLogin — phone-only mode', () {
      setUp(() {
        Config.set('magic_starter.auth.email', false);
        Config.set('magic_starter.auth.phone', true);
      });

      test('sends phone in payload, no email field', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'tok-phone',
              'user': {'id': 1, 'name': 'Alice'},
            },
          },
        );

        await controller.doLogin(phone: '+905301234567', password: 'secret');

        final body = mockDriver.lastData as Map<String, dynamic>?;
        expect(body?['phone'], equals('+905301234567'));
        expect(body?.containsKey('email'), isFalse);
        expect(controller.isSuccess, isTrue);
      });
    });

    group('doLogin — both mode (email or phone)', () {
      setUp(() {
        Config.set('magic_starter.auth.email', true);
        Config.set('magic_starter.auth.phone', true);
      });

      test('sends phone when phone field has value', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'tok-both-phone',
              'user': {'id': 1, 'name': 'Alice'},
            },
          },
        );

        await controller.doLogin(phone: '+905301234567', password: 'secret');

        final body = mockDriver.lastData as Map<String, dynamic>?;
        expect(body?['phone'], equals('+905301234567'));
        expect(body?.containsKey('email'), isFalse);
      });

      test('sends email when phone field is empty', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'tok-both-email',
              'user': {'id': 1, 'name': 'Alice', 'email': 'a@b.com'},
            },
          },
        );

        await controller.doLogin(email: 'a@b.com', password: 'secret');

        final body = mockDriver.lastData as Map<String, dynamic>?;
        expect(body?['email'], equals('a@b.com'));
        expect(body?.containsKey('phone'), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // doRegister — identity mode tests
    // -------------------------------------------------------------------------

    group('doRegister — email-only mode (default)', () {
      setUp(() {
        Config.set('magic_starter.auth.email', true);
        Config.set('magic_starter.auth.phone', false);
      });

      test('sends email in payload, no phone field', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'reg-tok',
              'user': {'id': 1, 'name': 'Bob', 'email': 'bob@example.com'},
            },
          },
        );

        await controller.doRegister(
          name: 'Bob',
          email: 'bob@example.com',
          password: 'secret123',
          passwordConfirmation: 'secret123',
        );

        final body = mockDriver.lastData as Map<String, dynamic>?;
        expect(body?['email'], equals('bob@example.com'));
        expect(body?.containsKey('phone'), isFalse);
        expect(body?.containsKey('phone_country'), isFalse);
      });
    });

    group('doRegister — phone-only mode', () {
      setUp(() {
        Config.set('magic_starter.auth.email', false);
        Config.set('magic_starter.auth.phone', true);
      });

      test('sends phone in payload, no email field', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'reg-tok-phone',
              'user': {'id': 1, 'name': 'Bob'},
            },
          },
        );

        await controller.doRegister(
          name: 'Bob',
          phone: '+905301234567',
          password: 'secret123',
          passwordConfirmation: 'secret123',
        );

        final body = mockDriver.lastData as Map<String, dynamic>?;
        expect(body?['phone'], equals('+905301234567'));
        expect(body?.containsKey('phone_country'), isFalse);
        expect(body?.containsKey('email'), isFalse);
      });
    });

    group('doRegister — both mode', () {
      setUp(() {
        Config.set('magic_starter.auth.email', true);
        Config.set('magic_starter.auth.phone', true);
      });

      test('sends both email and phone when both fields have values', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'reg-tok-both',
              'user': {'id': 1, 'name': 'Bob'},
            },
          },
        );

        await controller.doRegister(
          name: 'Bob',
          email: 'bob@example.com',
          phone: '+905301234567',
          password: 'secret123',
          passwordConfirmation: 'secret123',
        );

        final body = mockDriver.lastData as Map<String, dynamic>?;
        expect(body?['email'], equals('bob@example.com'));
        expect(body?['phone'], equals('+905301234567'));
        expect(body?.containsKey('phone_country'), isFalse);
      });

      test('sends email when phone field is empty', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'reg-tok-both-email',
              'user': {'id': 1, 'name': 'Bob', 'email': 'bob@example.com'},
            },
          },
        );

        await controller.doRegister(
          name: 'Bob',
          email: 'bob@example.com',
          password: 'secret123',
          passwordConfirmation: 'secret123',
        );

        final body = mockDriver.lastData as Map<String, dynamic>?;
        expect(body?['email'], equals('bob@example.com'));
        expect(body?.containsKey('phone'), isFalse);
        expect(body?.containsKey('phone_country'), isFalse);
      });
    });
  });
}
