import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;
  Completer<MagicResponse>? _pendingResponse;

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

  void startPendingResponse() {
    _pendingResponse = Completer<MagicResponse>();
  }

  void completePendingResponse({
    required int statusCode,
    dynamic data,
  }) {
    _pendingResponse?.complete(
      MagicResponse(
        data: data ?? <String, dynamic>{},
        statusCode: statusCode,
      ),
    );
    _pendingResponse = null;
  }

  Future<MagicResponse> _respond(
    String method,
    String url, {
    dynamic data,
  }) async {
    lastMethod = method;
    lastUrl = url;
    lastData = data;

    if (_pendingResponse != null) {
      return _pendingResponse!.future;
    }

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
      _respond(
        'GET',
        url,
      );

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond(
        'POST',
        url,
        data: data,
      );

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond(
        'PUT',
        url,
        data: data,
      );

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      _respond(
        'DELETE',
        url,
      );

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _respond(
        'INDEX',
        resource,
      );

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond(
        'SHOW',
        '$resource/$id',
      );

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond(
        'STORE',
        resource,
        data: data,
      );

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond(
        'UPDATE',
        '$resource/$id',
        data: data,
      );

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond(
        'DESTROY',
        '$resource/$id',
      );

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
      _respond(
        'UPLOAD',
        url,
        data: data,
      );
}

class MockGuard implements Guard {
  Authenticatable? _user;
  bool logoutCalled = false;
  String? mockToken = 'mock-token';

  @override
  Future<void> login(
    Map<String, dynamic> data,
    Authenticatable user,
  ) async {
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
      _user = MagicStarterAuthUser.fromMap(
        <String, dynamic>{
          'id': 1,
          'name': 'Restored User',
        },
      );
    }
  }

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier<int>(0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StarterProfileController two-factor methods', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late StarterProfileController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      mockDriver = MockNetworkDriver();
      Magic.singleton('network', () => mockDriver);
      Magic.singleton('log', () => LogManager());

      mockGuard = MockGuard();
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', <String, dynamic>{
        'mock': <String, dynamic>{'driver': 'mock'},
      });

      Magic.singleton('magic_starter', () => MagicStarterManager());
      controller = StarterProfileController();
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
    });

    group('doEnableTwoFactor', () {
      test('success: loading to success and returns setup payload', () async {
        mockDriver.startPendingResponse();

        final Future<Map<String, dynamic>?> future =
            controller.doEnableTwoFactor();
        expect(controller.isLoading, isTrue);

        mockDriver.completePendingResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'data': <String, dynamic>{
              'secret': 'BASE32SECRET',
              'qr_url': 'otpauth://totp/app:user?secret=BASE32SECRET',
              'qr_svg': '<svg>...</svg>',
              'recovery_codes': <String>[
                'code-1',
                'code-2',
              ],
            },
          },
        );

        final Map<String, dynamic>? result = await future;

        expect(result, isNotNull);
        expect(result?['secret'], equals('BASE32SECRET'));
        expect(result?['recovery_codes'], isA<List<String>>());
        expect(mockDriver.lastMethod, equals('POST'));
        expect(mockDriver.lastUrl, equals('/two-factor-authentication'));
        expect(controller.isLoading, isFalse);
        expect(controller.isSuccess, isTrue);
      });

      test('failure: loading to error and returns null', () async {
        mockDriver.startPendingResponse();

        final Future<Map<String, dynamic>?> future =
            controller.doEnableTwoFactor();
        expect(controller.isLoading, isTrue);

        mockDriver.completePendingResponse(
          statusCode: 500,
          data: <String, dynamic>{
            'message': 'Server error',
          },
        );

        final Map<String, dynamic>? result = await future;

        expect(result, isNull);
        expect(controller.isLoading, isFalse);
        expect(controller.isError, isTrue);
      });
    });

    group('doConfirmTwoFactor', () {
      test('success: loading to success and posts OTP code', () async {
        mockDriver.startPendingResponse();

        final Future<bool> future = controller.doConfirmTwoFactor(
          code: '123456',
        );
        expect(controller.isLoading, isTrue);

        mockDriver.completePendingResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'message': 'Two factor confirmed.',
          },
        );

        final bool result = await future;

        expect(result, isTrue);
        expect(mockDriver.lastMethod, equals('POST'));
        expect(
            mockDriver.lastUrl, equals('/two-factor-authentication/confirm'));
        expect(
          mockDriver.lastData,
          equals(
            <String, dynamic>{
              'code': '123456',
            },
          ),
        );
        expect(controller.isLoading, isFalse);
        expect(controller.isSuccess, isTrue);
      });

      test('failure: loading to error on wrong OTP', () async {
        mockDriver.startPendingResponse();

        final Future<bool> future = controller.doConfirmTwoFactor(
          code: '000000',
        );
        expect(controller.isLoading, isTrue);

        mockDriver.completePendingResponse(
          statusCode: 422,
          data: <String, dynamic>{
            'message': 'Invalid two-factor code.',
            'errors': <String, dynamic>{
              'code': <String>[
                'Invalid code.',
              ],
            },
          },
        );

        final bool result = await future;

        expect(result, isFalse);
        expect(controller.isLoading, isFalse);
        expect(controller.isError, isTrue);
      });
    });

    group('doDisableTwoFactor', () {
      test('success: loading to success and sends password', () async {
        mockDriver.startPendingResponse();

        final Future<bool> future = controller.doDisableTwoFactor(
          password: 'valid-password',
        );
        expect(controller.isLoading, isTrue);

        mockDriver.completePendingResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'message': 'Two factor disabled.',
          },
        );

        final bool result = await future;

        expect(result, isTrue);
        expect(mockDriver.lastMethod, equals('POST'));
        expect(mockDriver.lastUrl, equals('/two-factor-authentication'));
        expect(
          mockDriver.lastData,
          equals(
            <String, dynamic>{
              '_method': 'DELETE',
              'password': 'valid-password',
            },
          ),
        );
        expect(controller.isLoading, isFalse);
        expect(controller.isSuccess, isTrue);
      });

      test('failure: loading to error on wrong password', () async {
        mockDriver.startPendingResponse();

        final Future<bool> future = controller.doDisableTwoFactor(
          password: 'wrong-password',
        );
        expect(controller.isLoading, isTrue);

        mockDriver.completePendingResponse(
          statusCode: 422,
          data: <String, dynamic>{
            'message': 'Invalid password.',
            'errors': <String, dynamic>{
              'password': <String>[
                'The password is incorrect.',
              ],
            },
          },
        );

        final bool result = await future;

        expect(result, isFalse);
        expect(controller.isLoading, isFalse);
        expect(controller.isError, isTrue);
      });
    });

    group('getRecoveryCodes', () {
      test('success: loading to success and returns codes', () async {
        mockDriver.startPendingResponse();

        final Future<List<String>?> future = controller.getRecoveryCodes();
        expect(controller.isLoading, isTrue);

        mockDriver.completePendingResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'code': 'rc-1',
                'used_at': null,
              },
              <String, dynamic>{
                'code': 'rc-2',
                'used_at': '2026-03-01T09:00:00Z',
              },
            ],
          },
        );

        final List<String>? result = await future;

        expect(result, isNotNull);
        expect(result?.length, equals(2));
        expect(result?[0], contains('rc-1'));
        expect(mockDriver.lastMethod, equals('GET'));
        expect(mockDriver.lastUrl, equals('/two-factor-recovery-codes'));
        expect(controller.isLoading, isFalse);
        expect(controller.isSuccess, isTrue);
      });

      test('failure: loading to error and returns null', () async {
        mockDriver.startPendingResponse();

        final Future<List<String>?> future = controller.getRecoveryCodes();
        expect(controller.isLoading, isTrue);

        mockDriver.completePendingResponse(
          statusCode: 500,
          data: <String, dynamic>{
            'message': 'Server error',
          },
        );

        final List<String>? result = await future;

        expect(result, isNull);
        expect(controller.isLoading, isFalse);
        expect(controller.isError, isTrue);
      });
    });

    group('doRegenerateRecoveryCodes', () {
      test('success: loading to success and returns regenerated list',
          () async {
        mockDriver.startPendingResponse();

        final Future<List<String>?> future =
            controller.doRegenerateRecoveryCodes();
        expect(controller.isLoading, isTrue);

        mockDriver.completePendingResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'data': <String>[
              'new-code-1',
              'new-code-2',
              'new-code-3',
            ],
          },
        );

        final List<String>? result = await future;

        expect(result, isNotNull);
        expect(
          result,
          equals(
            <String>[
              'new-code-1',
              'new-code-2',
              'new-code-3',
            ],
          ),
        );
        expect(mockDriver.lastMethod, equals('POST'));
        expect(mockDriver.lastUrl, equals('/two-factor-recovery-codes'));
        expect(controller.isLoading, isFalse);
        expect(controller.isSuccess, isTrue);
      });

      test('failure: loading to error and returns null', () async {
        mockDriver.startPendingResponse();

        final Future<List<String>?> future =
            controller.doRegenerateRecoveryCodes();
        expect(controller.isLoading, isTrue);

        mockDriver.completePendingResponse(
          statusCode: 500,
          data: <String, dynamic>{
            'message': 'Unable to regenerate.',
          },
        );

        final List<String>? result = await future;

        expect(result, isNull);
        expect(controller.isLoading, isFalse);
        expect(controller.isError, isTrue);
      });
    });

    group('isTwoFactorEnabled getter', () {
      test('returns true when user has two_factor_enabled: true', () {
        mockGuard.setUser(
          MagicStarterAuthUser.fromMap(
            <String, dynamic>{
              'id': 1,
              'name': 'Test User',
              'two_factor_enabled': true,
            },
          ),
        );
        expect(controller.isTwoFactorEnabled, isTrue);
      });

      test('returns false when user has two_factor_enabled: false', () {
        mockGuard.setUser(
          MagicStarterAuthUser.fromMap(
            <String, dynamic>{
              'id': 1,
              'name': 'Test User',
              'two_factor_enabled': false,
            },
          ),
        );
        expect(controller.isTwoFactorEnabled, isFalse);
      });

      test('returns false when user has no two_factor_enabled field', () {
        mockGuard.setUser(
          MagicStarterAuthUser.fromMap(
            <String, dynamic>{
              'id': 1,
              'name': 'Test User',
            },
          ),
        );
        expect(controller.isTwoFactorEnabled, isFalse);
      });
    });
  });
}
