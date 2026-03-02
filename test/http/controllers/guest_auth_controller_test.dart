import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// MockNetworkDriver — intercepts all Http facade calls.
// Shared pattern from auth_controller_test.dart.
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
// MockGuard — tracks Auth.login() / Auth.logout() calls.
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

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
}

// ---------------------------------------------------------------------------
// MockVaultService — in-memory vault for testing without platform channels.
// ---------------------------------------------------------------------------

class MockVaultService extends MagicVaultService {
  final Map<String, String> _store = {};

  @override
  Future<void> put(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> get(String key) async {
    return _store[key];
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> flush() async {
    _store.clear();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StarterGuestAuthController', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late MockVaultService mockVault;
    late StarterGuestAuthController controller;

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

      // 6. Bind mock vault service for Vault facade.
      mockVault = MockVaultService();
      Magic.singleton('vault', () => mockVault);

      // 7. Create a fresh controller instance.
      controller = StarterGuestAuthController();

      // 8. Resolve the mock driver for response setup.
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
    });

    // -----------------------------------------------------------------------
    // doGuestLogin
    // -----------------------------------------------------------------------

    group('doGuestLogin', () {
      test('success — generates UUID and calls POST /auth/guest', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'guest-token-abc',
              'user': {
                'id': 99,
                'name': 'Guest User',
                'is_guest': true,
              },
            },
          },
        );

        await controller.doGuestLogin();

        expect(mockDriver.lastUrl, equals('/auth/guest'));
        expect(mockDriver.lastMethod, equals('POST'));

        // 1. Verify a non-empty device_id UUID was sent.
        final sentData = mockDriver.lastData as Map<String, dynamic>?;
        expect(sentData, isNotNull);
        final deviceId = sentData!['device_id'] as String?;
        expect(deviceId, isNotNull);
        expect(deviceId, isNotEmpty);

        // 2. Validate UUID v4 format (xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx).
        final uuidPattern = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        );
        expect(uuidPattern.hasMatch(deviceId!), isTrue,
            reason: 'device_id must be a valid UUID v4, got: $deviceId');
      });

      test('success — stores UUID in Vault', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'guest-token-abc',
              'user': {
                'id': 99,
                'name': 'Guest User',
                'is_guest': true,
              },
            },
          },
        );

        await controller.doGuestLogin();

        // Verify the generated UUID was persisted in the vault.
        final storedId = await mockVault.get('guest_device_id');
        expect(storedId, isNotNull);
        expect(storedId, isNotEmpty);

        final uuidPattern = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        );
        expect(uuidPattern.hasMatch(storedId!), isTrue);
      });

      test('success — calls Auth.login with token from response', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'guest-token-xyz',
              'user': {
                'id': 99,
                'name': 'Guest User',
                'is_guest': true,
              },
            },
          },
        );

        await controller.doGuestLogin();

        expect(mockGuard.check(), isTrue);
        expect(
          mockGuard.lastLoginData?['token'],
          equals('guest-token-xyz'),
        );
      });

      test('success — reuses stored UUID on subsequent calls', () async {
        // Pre-populate the vault with an existing UUID.
        const existingId = '12345678-1234-4abc-8def-123456789abc';
        await mockVault.put('guest_device_id', existingId);

        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'guest-token-reused',
              'user': {
                'id': 99,
                'name': 'Guest User',
                'is_guest': true,
              },
            },
          },
        );

        await controller.doGuestLogin();

        final sentData = mockDriver.lastData as Map<String, dynamic>?;
        expect(sentData?['device_id'], equals(existingId));
      });

      test('API error — sets error state', () async {
        mockDriver.mockResponse(
          statusCode: 400,
          data: {
            'message': 'Guest login not supported',
          },
        );

        await controller.doGuestLogin();

        expect(controller.isError, isTrue);
        expect(mockGuard.check(), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // getStoredDeviceId
    // -----------------------------------------------------------------------

    group('getStoredDeviceId', () {
      test('returns null when no device ID has been stored', () async {
        final result = await controller.getStoredDeviceId();

        expect(result, isNull);
      });

      test('returns the stored UUID after doGuestLogin completes', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'guest-token-abc',
              'user': {
                'id': 99,
                'name': 'Guest User',
                'is_guest': true,
              },
            },
          },
        );

        await controller.doGuestLogin();

        final storedId = await controller.getStoredDeviceId();
        expect(storedId, isNotNull);
        expect(storedId, isNotEmpty);
      });
    });
  });
}
