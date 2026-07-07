import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
// The sub-page view is registered via the view registry (key `profile.profile`)
// and wired into the barrel in Step 11; import directly here for the test.
import 'package:magic_starter/src/ui/views/profile/magic_starter_profile_sub_page_view.dart';

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
          body: widget,
        ),
      ),
    );
  }

  group('MagicStarterProfileSubPageView', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      MagicApp.reset();
      Magic.flush();

      Config.set('magic_starter.features.extended_profile', true);
      Config.set('magic_starter.features.profile_photo', true);
      Config.set('magic_starter.features.email_verification', true);

      mockDriver = MockNetworkDriver();
      Magic.singleton('network', () => mockDriver);
      Magic.singleton('log', () => LogManager());

      mockGuard = MockGuard();
      Magic.singleton('auth', () => AuthManager());
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {
          'driver': 'mock',
        },
      });

      mockGuard.setUser(
        MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Test User',
          'email': 'test@example.com',
          'phone': '+905301234567',
          'timezone': 'Europe/Istanbul',
          'language': 'tr',
        }),
      );

      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.put(MagicStarterProfileController());

      Gate.flush();
      Gate.define('starter.update-profile-photo', (user, [_]) => true);
      Gate.define('starter.update-email', (user, [_]) => true);
      Gate.define('starter.update-phone', (user, [_]) => true);
      Gate.define('starter.verify-email', (user, [_]) => true);
      Gate.define('starter.delete-account', (user, [_]) => true);
    });

    tearDown(() {
      Auth.manager.forgetGuards();
      Gate.flush();
    });

    testWidgets('renders inside a SettingsScaffold with Settings back label',
        (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterProfileSubPageView()));

      expect(find.byType(MSSettingsScaffold), findsOneWidget);

      final scaffold = tester.widget<MSSettingsScaffold>(
        find.byType(MSSettingsScaffold),
      );
      expect(scaffold.backLabel, isNotNull);
      expect(scaffold.backFallback, MagicStarterConfig.settingsHubRoute());
    });

    testWidgets('renders the profile information form fields', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterProfileSubPageView()));

      // Name / email / phone inputs are present. Timezone and language live on
      // their own dedicated Preferences sub-pages, so they must NOT be
      // duplicated on the Profile sub-page.
      expect(find.byType(WFormInput), findsWidgets);
      expect(find.byType(WFormSelect<String>), findsNothing);
      expect(find.byType(MagicStarterTimezoneSelect), findsNothing);
    });

    testWidgets('profile save submits to /user/profile', (tester) async {
      mockDriver.mockResponse(statusCode: 200, data: {'data': {}});

      await tester.pumpWidget(wrap(const MagicStarterProfileSubPageView()));

      final saveButton = find.widgetWithText(WButton, 'common.save');
      expect(saveButton, findsOneWidget);

      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(mockDriver.lastMethod, 'PUT');
      expect(mockDriver.lastUrl, contains('/user/profile'));
    });

    testWidgets('backend validation errors display after a failed save',
        (tester) async {
      mockDriver.mockResponse(
        statusCode: 422,
        data: {
          'message': 'The given data was invalid.',
          'errors': {
            'name': ['The name field is required.'],
          },
        },
      );

      await tester.pumpWidget(wrap(const MagicStarterProfileSubPageView()));

      final saveButton = find.widgetWithText(WButton, 'common.save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('The name field is required.'), findsOneWidget);
    });

    testWidgets('does NOT render a Delete Account row (moved to Sessions)',
        (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterProfileSubPageView()));

      // Account deletion now lives on the Security > Sessions sub-page, not on
      // the Profile form. No destructive row should be present here.
      final rows = tester.widgetList<MSSettingsRow>(find.byType(MSSettingsRow));
      final destructiveRows = rows.where(
        (row) => row.tone == SettingsRowTone.destructive,
      );
      expect(destructiveRows, isEmpty);
    });

    testWidgets('email verification resend submits when unverified',
        (tester) async {
      // Unverified user (no email_verified_at).
      mockDriver.mockResponse(statusCode: 200, data: {});

      await tester.pumpWidget(wrap(const MagicStarterProfileSubPageView()));

      final resendButton = find.widgetWithText(
        WButton,
        'magic_starter.email_verification.resend_button',
      );
      expect(resendButton, findsOneWidget);

      await tester.ensureVisible(resendButton);
      await tester.pumpAndSettle();
      await tester.tap(resendButton);
      await tester.pumpAndSettle();

      expect(mockDriver.lastMethod, 'POST');
      expect(mockDriver.lastUrl, contains('/email/verification-notification'));
    });

    testWidgets('does not render password / sessions / 2FA sections',
        (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterProfileSubPageView()));

      // These live on their own Security sub-pages (Step 9).
      expect(find.text('profile.update_password'), findsNothing);
      expect(find.text('profile.browser_sessions'), findsNothing);
      expect(find.text('profile.two_factor_authentication'), findsNothing);
    });
  });
}
