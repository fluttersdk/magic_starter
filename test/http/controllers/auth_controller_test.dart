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
// Mock Guard — tracks Auth.login() / Auth.logout() calls
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool logoutCalled = false;
  Map<String, dynamic>? lastLoginData;
  String? mockToken = 'mock-token';

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
      _user = MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Restored User',
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('StarterAuthController', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late StarterAuthController controller;

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
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {
          'driver': 'mock',
        },
      });

      // 5. Bind MagicStarterManager for MagicStarter facade.
      Magic.singleton('magic_starter', () => MagicStarterManager());

      // 6. Create a fresh controller instance.
      controller = StarterAuthController();

      // 7. Resolve the mock driver for response setup.
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
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
              'user': {
                'id': 1,
                'name': 'Alice',
                'email': 'alice@example.com',
              },
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

        await controller.doLogin(
          email: 'bad@example.com',
          password: 'wrong',
        );

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

        final future1 = controller.doLogin(
          email: 'a@b.com',
          password: 'pass',
        );
        // Second call should be a no-op (already submitting).
        final future2 = controller.doLogin(
          email: 'a@b.com',
          password: 'pass',
        );

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

        await controller.doLogin(
          email: 'a@b.com',
          password: 'pass',
        );

        expect(controller.isSuccess, isTrue);
        expect(mockGuard.check(), isTrue);
      });

      test('intercepts 2fa response at root level', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'two_factor': true,
            'two_factor_token': 'enc-tok-123',
          },
        );

        await controller.doLogin(
          email: 'a@b.com',
          password: 'pass',
        );

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
            'data': {
              'two_factor': true,
              'two_factor_token': 'enc-tok-123',
            },
          },
        );

        await controller.doLogin(
          email: 'a@b.com',
          password: 'pass',
        );

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
              'user': {
                'id': 2,
                'name': 'Bob',
                'email': 'bob@example.com',
              },
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

      test('success without token — sets success without login', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'message': 'Verification email sent',
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
    // logout
    // ---------------------------------------------------------------------

    group('logout', () {
      test('calls Auth.logout()', () async {
        await controller.logout();

        expect(mockGuard.logoutCalled, isTrue);
      });
    });
  });
}
