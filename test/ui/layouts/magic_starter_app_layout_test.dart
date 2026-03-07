import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';
import 'package:magic_starter/magic_starter.dart';

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;
  String? lastMethod;
  String? lastUrl;
  int notificationGetCallCount = 0;

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

    if (method == 'GET' && url == '/notifications') {
      notificationGetCallCount++;
    }

    return nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  }

  void resetTracking() {
    lastMethod = null;
    lastUrl = null;
    notificationGetCallCount = 0;
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async =>
      _respond('GET', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _respond('INDEX', resource);

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
  final ValueNotifier<int> _stateNotifier = ValueNotifier<int>(0);

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  Future<String?> getToken() async => 'mock-token';

  @override
  Future<bool> hasToken() async => _user != null;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  Future<void> login(
    Map<String, dynamic> data,
    Authenticatable user,
  ) async {
    _user = user;
    _stateNotifier.value++;
  }

  @override
  Future<void> logout() async {
    _user = null;
    _stateNotifier.value++;
  }

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {}

  @override
  void setUser(Authenticatable user) => _user = user;

  @override
  ValueNotifier<int> get stateNotifier => _stateNotifier;

  @override
  T? user<T extends Model>() => _user as T?;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNetworkDriver mockDriver;

  setUp(() {
    MagicApp.reset();
    Magic.flush();

    Magic.singleton(
      'network',
      () => MockNetworkDriver(),
    );

    Magic.singleton(
      'log',
      () => LogManager(),
    );
    Config.set(
      'logging',
      {
        'default': 'console',
        'channels': {
          'console': {
            'driver': 'console',
            'level': 'debug',
          },
        },
      },
    );

    final mockGuard = MockGuard();
    Auth.manager.forgetGuards();
    Auth.manager.extend(
      'mock',
      (_) => mockGuard,
    );
    Config.set('auth.defaults.guard', 'mock');
    Config.set(
      'auth.guards',
      {
        'mock': {
          'driver': 'mock',
        },
      },
    );

    Magic.singleton(
      'magic_starter',
      () => MagicStarterManager(),
    );

    MagicStarter.useNavigation(mainItems: const []);

    mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    mockDriver.mockResponse(
      statusCode: 200,
      data: {
        'data': [],
      },
    );
  });

  tearDown(() {
    Auth.manager.forgetGuards();

    try {
      Notify.stopPolling();
    } catch (_) {}
  });

  GoRouter createRouter({
    required Widget child,
  }) {
    return GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MagicStarterAppLayout(
            child: child,
          ),
        ),
      ],
    );
  }

  Widget createApp({
    required Widget child,
  }) {
    final router = createRouter(child: child);

    return WindTheme(
      data: WindThemeData(),
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('MagicStarterAppLayout dispose', () {
    testWidgets(
      'stops notification polling when layout is disposed and features enabled',
      (tester) async {
        Config.set('magic_starter.features.notifications', true);

        await tester.pumpWidget(
          createApp(
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, greaterThan(0));

        mockDriver.resetTracking();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Disposed'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.pump(
          const Duration(seconds: 31),
        );
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, equals(0));
      },
    );

    testWidgets(
      'does not start notification polling when feature is disabled',
      (tester) async {
        Config.set('magic_starter.features.notifications', false);

        await tester.pumpWidget(
          createApp(
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, equals(0));

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Disposed'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.pump(
          const Duration(seconds: 31),
        );
        await tester.pumpAndSettle();

        expect(mockDriver.notificationGetCallCount, equals(0));
      },
    );
  });
}
