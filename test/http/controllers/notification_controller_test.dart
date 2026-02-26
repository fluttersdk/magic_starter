import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/http/controllers/notification_controller.dart';

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

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier<int>(0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StarterNotificationController', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late StarterNotificationController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      Magic.singleton('network', () => MockNetworkDriver());
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {
            'driver': 'console',
            'level': 'debug',
          },
        },
      });

      mockGuard = MockGuard();
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {
          'driver': 'mock',
        },
      });

      Magic.singleton('magic_starter', () => MagicStarterManager());
      controller = StarterNotificationController();
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
    });

    test('index() returns a Widget (view registry resolves)', () {
      MagicStarter.view.register('notifications.list', () => const SizedBox());
      final widget = controller.index();
      expect(widget, isA<Widget>());
    });

    test('preferences() returns a Widget (view registry resolves)', () {
      MagicStarter.view
          .register('notifications.preferences', () => const SizedBox());
      final widget = controller.preferences();
      expect(widget, isA<Widget>());
    });

    test('fetchPreferences success — populates matrixNotifier', () async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': {
            'monitor_down': {
              'label': 'Monitor Down',
              'channels': {
                'mail': {
                  'enabled': true,
                  'locked': false,
                },
              },
            },
          },
        },
      );

      await controller.fetchPreferences();

      expect(controller.matrixNotifier.value['monitor_down'], isNotNull);
      expect(
        controller.matrixNotifier.value['monitor_down']['channels']['mail']
            ['enabled'],
        isTrue,
      );
    });

    test('fetchPreferences error (500) — keeps matrixNotifier empty', () async {
      mockDriver.mockResponse(statusCode: 500);

      await controller.fetchPreferences();

      expect(controller.matrixNotifier.value.isEmpty, isTrue);
    });

    test('updateTypePreference success — matrix updated optimistically',
        () async {
      controller.matrixNotifier.value = {
        'monitor_down': {
          'label': 'Monitor Down',
          'channels': {
            'mail': {
              'enabled': true,
              'locked': false,
            },
          },
        },
      };

      mockDriver.mockResponse(statusCode: 200);

      await controller.updateTypePreference('monitor_down', 'mail', false);

      expect(
        controller.matrixNotifier.value['monitor_down']['channels']['mail']
            ['enabled'],
        isFalse,
      );
      expect(mockDriver.lastMethod, equals('PUT'));
      expect(mockDriver.lastUrl, equals('/notification-preferences'));
    });

    test('updateTypePreference failure — reverts to original matrix', () async {
      final originalMatrix = {
        'monitor_down': {
          'label': 'Monitor Down',
          'channels': {
            'mail': {
              'enabled': true,
              'locked': false,
            },
          },
        },
      };
      controller.matrixNotifier.value = originalMatrix;

      mockDriver.mockResponse(statusCode: 422);

      await controller.updateTypePreference('monitor_down', 'mail', false);

      expect(
        controller.matrixNotifier.value['monitor_down']['channels']['mail']
            ['enabled'],
        isTrue,
      );
    });
  });
}
