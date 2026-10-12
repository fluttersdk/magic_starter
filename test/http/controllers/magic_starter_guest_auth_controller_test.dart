import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Every request sent, so a test can count them.
  int requestCount = 0;

  /// Thrown from the next request instead of answering, the way a dead link
  /// surfaces through the driver.
  Object? failWith;

  /// Runs while the next request is in flight, before it answers, so a test
  /// can change the session underneath it.
  void Function()? duringRequest;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(data: data ?? {}, statusCode: statusCode);
  }

  MagicResponse _respond(String method, String url, {dynamic data}) {
    requestCount++;
    final inFlight = duringRequest;
    duringRequest = null;
    inFlight?.call();
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw failure;
    }

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
// MockGuard — tracks Auth.login() / Auth.logout() calls.
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool logoutCalled = false;
  Map<String, dynamic>? lastLoginData;
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

  group('MagicStarterGuestAuthController', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late MockVaultService mockVault;
    late MagicStarterGuestAuthController controller;

    setUp(() {
      // 1. Reset IoC container.
      MagicApp.reset();
      Magic.flush();
      MagicRouter.reset();

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

      // 6. Bind mock vault service for Vault facade.
      mockVault = MockVaultService();
      Magic.singleton('vault', () => mockVault);

      // 7. Create a fresh controller instance.
      controller = MagicStarterGuestAuthController();

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
      test('a signed-in guest continues without a second request', () async {
        // A guest can reach the login page now, and "Continue as guest" is its
        // only way back. A second POST /auth/guest revokes every token of a
        // returning guest, including the one a host holds to claim the
        // guest's data later, so the session already in hand must be kept.
        mockGuard.setUser(
          MagicStarterAuthUser.fromMap({
            'id': 99,
            'name': 'Guest',
            'is_guest': true,
          }),
        );

        await controller.doGuestLogin();

        expect(mockDriver.lastUrl, isNull);
      });

      testWidgets('success goes home', (tester) async {
        MagicRoute.page('/', () => const Text('home'));
        MagicRoute.page('/login', () => const Text('login'));
        MagicRouter.instance.setInitialLocation('/login');
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'guest-token-abc',
              'user': {'id': 99, 'name': 'Guest User', 'is_guest': true},
            },
          },
        );

        await controller.doGuestLogin();
        await tester.pumpAndSettle();

        expect(MagicRouter.instance.currentPath, '/');
        expect(controller.isSuccess, isTrue);
      });

      test('success — generates UUID and calls POST /auth/guest', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'guest-token-abc',
              'user': {'id': 99, 'name': 'Guest User', 'is_guest': true},
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
        expect(
          uuidPattern.hasMatch(deviceId!),
          isTrue,
          reason: 'device_id must be a valid UUID v4, got: $deviceId',
        );
      });

      test('success — stores UUID in Vault', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'guest-token-abc',
              'user': {'id': 99, 'name': 'Guest User', 'is_guest': true},
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
              'user': {'id': 99, 'name': 'Guest User', 'is_guest': true},
            },
          },
        );

        await controller.doGuestLogin();

        expect(mockGuard.check(), isTrue);
        expect(mockGuard.lastLoginData?['token'], equals('guest-token-xyz'));
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
              'user': {'id': 99, 'name': 'Guest User', 'is_guest': true},
            },
          },
        );

        await controller.doGuestLogin();

        final sentData = mockDriver.lastData as Map<String, dynamic>?;
        expect(sentData?['device_id'], equals(existingId));
      });

      test('a body without a token is an error, not a signed-out trip '
          'home', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'user': {'id': 99, 'name': 'Guest User', 'is_guest': true},
            },
          },
        );

        await controller.doGuestLogin();

        expect(controller.isError, isTrue);
        expect(mockGuard.check(), isFalse);
      });

      test('API error — sets error state', () async {
        mockDriver.mockResponse(
          statusCode: 400,
          data: {'message': 'Guest login not supported'},
        );

        await controller.doGuestLogin();

        expect(controller.isError, isTrue);
        expect(mockGuard.check(), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // openGuestSession
    // -----------------------------------------------------------------------

    group('openGuestSession', () {
      void answerWithGuestSession() {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': {
              'token': 'guest-token-abc',
              'user': {'id': 99, 'name': 'Guest User', 'is_guest': true},
            },
          },
        );
      }

      test('two concurrent callers share one POST /auth/guest', () async {
        answerWithGuestSession();

        final results = await Future.wait([
          controller.openGuestSession(),
          controller.openGuestSession(),
        ]);

        expect(results, [isTrue, isTrue]);
        expect(mockDriver.requestCount, 1);
        expect(mockDriver.lastUrl, '/auth/guest');
        expect(mockGuard.check(), isTrue);
      });

      testWidgets('leaves the router where it is', (tester) async {
        MagicRoute.page('/', () => const Text('home'));
        MagicRoute.page('/monitors', () => const Text('monitors'));
        MagicRouter.instance.setInitialLocation('/monitors');
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();
        answerWithGuestSession();

        final opened = await controller.openGuestSession();
        await tester.pumpAndSettle();

        expect(opened, isTrue);
        expect(MagicRouter.instance.currentPath, '/monitors');
      });

      test('never offers the guest credentials to the keychain', () async {
        // A guest opened in the background is not a sign-in the viewer typed
        // credentials for, so the save prompt must not follow it.
        final calls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.textInput, (call) async {
              calls.add(call.method);

              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.textInput, null),
        );
        answerWithGuestSession();

        expect(await controller.openGuestSession(), isTrue);

        expect(calls, isNot(contains('TextInput.finishAutofillContext')));
      });

      test('a transport failure resolves false and signs nobody in', () async {
        mockDriver.failWith = Exception('connection refused');

        final opened = await controller.openGuestSession();

        expect(opened, isFalse);
        expect(Auth.check(), isFalse);
        expect(controller.isError, isTrue);
      });

      test('a call after a failure sends a fresh request', () async {
        mockDriver.failWith = Exception('connection refused');
        expect(await controller.openGuestSession(), isFalse);

        answerWithGuestSession();
        final opened = await controller.openGuestSession();

        expect(opened, isTrue);
        expect(mockDriver.requestCount, 2);
      });

      test('a rejected request resolves false', () async {
        mockDriver.mockResponse(
          statusCode: 403,
          data: {'message': 'Guest login is disabled'},
        );

        expect(await controller.openGuestSession(), isFalse);
        expect(mockGuard.check(), isFalse);
      });

      test('a signed-in guest resolves true without a request', () async {
        mockGuard.setUser(
          MagicStarterAuthUser.fromMap({
            'id': 99,
            'name': 'Guest',
            'is_guest': true,
          }),
        );

        expect(await controller.openGuestSession(), isTrue);
        expect(mockDriver.requestCount, 0);
      });

      test('a signed-in account is never replaced by a guest', () async {
        mockGuard.setUser(
          MagicStarterAuthUser.fromMap({'id': 1, 'name': 'Alice'}),
        );

        expect(await controller.openGuestSession(), isTrue);
        expect(mockDriver.requestCount, 0);
        expect(Auth.user()?.get<String>('name'), 'Alice');
      });

      test('an account signed in while the request flies is kept', () async {
        // The viewer reaches the login screen and signs in before a slow
        // background open answers: the guest it brings back must not replace
        // the account that now holds the session.
        mockDriver.duringRequest = () => mockGuard.setUser(
          MagicStarterAuthUser.fromMap({'id': 1, 'name': 'Alice'}),
        );
        answerWithGuestSession();

        expect(await controller.openGuestSession(), isTrue);
        expect(mockDriver.requestCount, 1);
        expect(mockGuard.lastLoginData, isNull);
        expect(Auth.user()?.get<String>('name'), 'Alice');
      });

      test('a stored token whose user is not loaded yet is kept', () async {
        // A cold boot on a dead link: `Auth.restore()` keeps the token and
        // loads no user, so `Auth.check()` is false over a real session.
        mockGuard.mockToken = 'stored-account-token';

        expect(await controller.openGuestSession(), isTrue);
        expect(mockDriver.requestCount, 0);
        expect(mockGuard.mockToken, 'stored-account-token');
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
              'user': {'id': 99, 'name': 'Guest User', 'is_guest': true},
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
