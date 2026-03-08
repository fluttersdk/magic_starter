import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Reuse MockNetworkDriver and MockGuard patterns from auth_controller_test
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

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MagicStarterOtpController', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late MagicStarterOtpController controller;

    setUp(() {
      // 1. Reset IoC container.
      MagicApp.reset();
      Magic.flush();

      // 2. Bind mock network driver for Http facade.
      mockDriver = MockNetworkDriver();
      Magic.singleton('network', () => mockDriver);

      // 3. Bind LogManager so Log.error() works in catch blocks.
      Magic.singleton('log', () => LogManager());

      // 4. Bind MockGuard for Auth facade.
      mockGuard = MockGuard();
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {'driver': 'mock'},
      });

      // 5. Bind MagicStarterManager.
      Magic.singleton('magic_starter', () => MagicStarterManager());

      // 6. Create controller.
      controller = MagicStarterOtpController();
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
    });

    // -----------------------------------------------------------------------
    // Initial state
    // -----------------------------------------------------------------------

    test('initial state: starts on phoneInput step', () {
      expect(controller.step, OtpStep.phoneInput);
      expect(controller.isLoading, isFalse);
      expect(controller.isError, isFalse);
    });

    // -----------------------------------------------------------------------
    // sendOtp
    // -----------------------------------------------------------------------

    test('sendOtp — success: transitions to codeInput step', () async {
      mockDriver.mockResponse(statusCode: 200, data: {});

      await controller.sendOtp(phone: '+905301234567');

      expect(mockDriver.lastMethod, 'POST');
      expect(mockDriver.lastUrl, '/auth/otp/send');
      expect(
        (mockDriver.lastData as Map<String, dynamic>)['phone'],
        '+905301234567',
      );
      expect(controller.step, OtpStep.codeInput);
      expect(controller.isLoading, isFalse);
      expect(controller.isError, isFalse);
    });

    test('sendOtp — API error: sets error state', () async {
      mockDriver.mockResponse(
        statusCode: 422,
        data: {
          'message': 'The phone field is required.',
          'errors': {
            'phone': ['The phone field is required.'],
          },
        },
      );

      await controller.sendOtp(phone: '');

      expect(controller.step, OtpStep.phoneInput);
      expect(controller.isError, isTrue);
      expect(controller.isLoading, isFalse);
    });

    test('sendOtp — stores phone number for verifyOtp step', () async {
      mockDriver.mockResponse(statusCode: 200, data: {});

      await controller.sendOtp(phone: '+905301234567');

      expect(controller.phoneNumber, '+905301234567');
    });

    // -----------------------------------------------------------------------
    // verifyOtp
    // -----------------------------------------------------------------------

    test('verifyOtp — success: Auth.login called with token', () async {
      // Arrange — get to code_input step first.
      mockDriver.mockResponse(statusCode: 200, data: {});
      await controller.sendOtp(phone: '+905301234567');

      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'token': 'otp-auth-token-123',
          'user': {
            'id': 1,
            'name': 'Test User',
            'email': 'test@example.com',
          },
        },
      );

      await controller.verifyOtp(
        phone: '+905301234567',
        code: '123456',
      );

      expect(mockDriver.lastMethod, 'POST');
      expect(mockDriver.lastUrl, '/auth/otp/verify');
      expect(
        (mockDriver.lastData as Map<String, dynamic>)['phone'],
        '+905301234567',
      );
      expect(
        (mockDriver.lastData as Map<String, dynamic>)['code'],
        '123456',
      );
      expect(mockGuard.lastLoginData?['token'], 'otp-auth-token-123');
      expect(controller.isError, isFalse);
    });

    test('verifyOtp — invalid code: sets error state, stays on code step',
        () async {
      // Arrange — get to code_input step first.
      mockDriver.mockResponse(statusCode: 200, data: {});
      await controller.sendOtp(phone: '+905301234567');

      mockDriver.mockResponse(
        statusCode: 422,
        data: {
          'message': 'The provided OTP code is invalid.',
          'errors': {
            'code': ['The provided OTP code is invalid.'],
          },
        },
      );

      await controller.verifyOtp(
        phone: '+905301234567',
        code: '000000',
      );

      expect(controller.step, OtpStep.codeInput);
      expect(controller.isError, isTrue);
      expect(controller.isLoading, isFalse);
      // Auth.login must NOT have been called.
      expect(mockGuard.check(), isFalse);
    });

    test('verifyOtp — expired code: sets error state', () async {
      // Arrange — get to code_input step first.
      mockDriver.mockResponse(statusCode: 200, data: {});
      await controller.sendOtp(phone: '+905301234567');

      mockDriver.mockResponse(
        statusCode: 422,
        data: {
          'message': 'The OTP code has expired.',
          'errors': {
            'code': ['The OTP code has expired.'],
          },
        },
      );

      await controller.verifyOtp(
        phone: '+905301234567',
        code: '111111',
      );

      expect(controller.isError, isTrue);
      expect(controller.step, OtpStep.codeInput);
    });

    // -----------------------------------------------------------------------
    // resetToPhoneInput
    // -----------------------------------------------------------------------

    test('resetToPhoneInput: returns to phoneInput step and clears error',
        () async {
      // Arrange — advance to code step.
      mockDriver.mockResponse(statusCode: 200, data: {});
      await controller.sendOtp(phone: '+905301234567');
      expect(controller.step, OtpStep.codeInput);

      controller.resetToPhoneInput();

      expect(controller.step, OtpStep.phoneInput);
    });
  });
}
