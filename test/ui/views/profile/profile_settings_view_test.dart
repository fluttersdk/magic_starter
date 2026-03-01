import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;
  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

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
  Future<MagicResponse> get(String url,
          {Map<String, dynamic>? query, Map<String, String>? headers}) async =>
      _respond('GET', url);

  @override
  Future<MagicResponse> post(String url,
          {dynamic data, Map<String, String>? headers}) async =>
      _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(String url,
          {dynamic data, Map<String, String>? headers}) async =>
      _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> delete(String url,
          {Map<String, String>? headers}) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> index(String resource,
          {Map<String, dynamic>? filters,
          Map<String, String>? headers}) async =>
      _respond('INDEX', resource);

  @override
  Future<MagicResponse> show(String resource, String id,
          {Map<String, String>? headers}) async =>
      _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(String resource, Map<String, dynamic> data,
          {Map<String, String>? headers}) async =>
      _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
          String resource, String id, Map<String, dynamic> data,
          {Map<String, String>? headers}) async =>
      _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> destroy(String resource, String id,
          {Map<String, String>? headers}) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(String url,
          {required Map<String, dynamic> data,
          required Map<String, dynamic> files,
          Map<String, String>? headers}) async =>
      _respond('UPLOAD', url, data: data);
}

// ---------------------------------------------------------------------------
// Mock Guard
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool logoutCalled = false;
  bool restoreCalled = false;
  String? mockToken = 'mock-token';

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
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
    restoreCalled = true;
    if (mockToken != null) {
      _user = MagicStarterAuthUser.fromMap({'id': 1, 'name': 'Restored User'});
    }
  }

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

  group('MagicStarterProfileSettingsView', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      MagicApp.reset();
      Magic.flush();

      // Config defaults
      Config.set('magic_starter.features.extended_profile', true);

      // 1. Bind mock network driver.
      mockDriver = MockNetworkDriver();
      Magic.singleton('network', () => mockDriver);

      // 2. Bind log manager.
      Magic.singleton('log', () => LogManager());

      // 3. Bind auth with mock guard.
      mockGuard = MockGuard();
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {
          'driver': 'mock',
        },
      });

      // 4. Set authenticated user.
      mockGuard.setUser(
        MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Test User',
          'email': 'test@example.com',
          'phone': '+905301234567',
          'phone_country': 'TR',
          'timezone': 'Europe/Istanbul',
          'language': 'tr',
        }),
      );

      // 5. Bind MagicStarterManager.
      Magic.singleton(
        'magic_starter',
        () => MagicStarterManager(),
      );

      // 6. Create and inject controller.
      Magic.put(StarterProfileController());
    });

    tearDown(() {
      Auth.manager.forgetGuards();
    });

    testWidgets('extended profile section renders when feature enabled',
        (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));

      // Verify extended profile section exists.
      expect(find.byKey(const Key('extended-profile-section')), findsOneWidget);

      // We use WFormInput, so let's find input by hint text or label.
      // Phone is in the form input controller, so it should be findable by text if value is rendered
      // 'name' and 'email' inputs should also exist
      expect(find.byType(WFormInput), findsWidgets);

      // Look for WFormSelect instances
      expect(find.byType(WFormSelect<String>), findsNWidgets(3));
    });

    testWidgets('extended profile section hides when feature disabled',
        (tester) async {
      Config.set('magic_starter.features.extended_profile', false);
      await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));

      // Verify extended profile section does not exist.
      expect(find.byKey(const Key('extended-profile-section')), findsNothing);
    });
  });
}
