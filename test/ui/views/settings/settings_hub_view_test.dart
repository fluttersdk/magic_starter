import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/views/settings/magic_starter_settings_hub_view.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;

  MagicResponse _respond(String method, String url, {dynamic data}) {
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
  String? mockToken = 'mock-token';

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    mockToken = data['token'] as String?;
    _user = user;
  }

  @override
  Future<void> logout() async {
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
  Future<void> restore() async {}

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
}

// ---------------------------------------------------------------------------
// Test Suite
// ---------------------------------------------------------------------------

void main() {
  late MockNetworkDriver mockDriver;
  late MockGuard mockGuard;

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: widget),
      ),
    );
  }

  /// Returns the [SettingsNavRow] whose `to` matches [path], or null.
  SettingsNavRow? navRowFor(WidgetTester tester, String path) {
    final rows = tester.widgetList<SettingsNavRow>(find.byType(SettingsNavRow));
    for (final row in rows) {
      if (row.to == path) {
        return row;
      }
    }
    return null;
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MagicApp.reset();
    Magic.flush();

    // 1. Network + log + auth scaffolding.
    mockDriver = MockNetworkDriver();
    Magic.singleton('network', () => mockDriver);
    Magic.singleton('log', () => LogManager());

    mockGuard = MockGuard();
    Magic.singleton('auth', () => AuthManager());
    Auth.manager.forgetGuards();
    Auth.manager.extend('mock', (_) => mockGuard);
    Config.set('auth.defaults.guard', 'mock');
    Config.set('auth.guards', {
      'mock': {'driver': 'mock'},
    });

    // 2. Authenticated, non-guest user.
    mockGuard.setUser(
      MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Test User',
        'email': 'test@example.com',
      }),
    );

    // 3. Starter manager + controller.
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Magic.put(MagicStarterProfileController());

    // 4. Default Gate abilities for a non-guest user (mirrors the service
    //    provider: every `starter.*` ability is granted to non-guests).
    Gate.flush();
    Gate.define('starter.update-password', (user, [_]) => true);
    Gate.define('starter.manage-two-factor', (user, [_]) => true);
    Gate.define('starter.manage-newsletter', (user, [_]) => true);
    Gate.define('starter.delete-account', (user, [_]) => true);
  });

  tearDown(() {
    Auth.manager.forgetGuards();
    Gate.flush();
    MagicApp.reset();
    Magic.flush();
  });

  // -------------------------------------------------------------------------
  // Account section — always present
  // -------------------------------------------------------------------------

  testWidgets(
      'always renders the Profile nav row pointing at the profile route',
      (tester) async {
    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    final row = navRowFor(tester, MagicStarterConfig.profileRoute());
    expect(row, isNotNull);
  });

  // -------------------------------------------------------------------------
  // Security section — feature gating toggles row presence
  // -------------------------------------------------------------------------

  testWidgets('Two-Factor row is hidden when the two-factor feature is off',
      (tester) async {
    Config.set('magic_starter.features.two_factor', false);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(
        navRowFor(tester, MagicStarterConfig.settingsTwoFactorRoute()), isNull);
  });

  testWidgets('Two-Factor row appears when the two-factor feature is on',
      (tester) async {
    Config.set('magic_starter.features.two_factor', true);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    final row = navRowFor(tester, MagicStarterConfig.settingsTwoFactorRoute());
    expect(row, isNotNull);
  });

  testWidgets('Sessions row appears only when the sessions feature is on',
      (tester) async {
    Config.set('magic_starter.features.sessions', true);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(
      navRowFor(tester, MagicStarterConfig.settingsSessionsRoute()),
      isNotNull,
    );
  });

  testWidgets('Sessions row is hidden when the sessions feature is off',
      (tester) async {
    Config.set('magic_starter.features.sessions', false);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(
      navRowFor(tester, MagicStarterConfig.settingsSessionsRoute()),
      isNull,
    );
  });

  // -------------------------------------------------------------------------
  // Preferences section — Appearance always present, others gated
  // -------------------------------------------------------------------------

  testWidgets('Appearance row is always present in Preferences',
      (tester) async {
    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(
      navRowFor(tester, MagicStarterConfig.settingsAppearanceRoute()),
      isNotNull,
    );
  });

  testWidgets('Notifications row appears only when notifications feature is on',
      (tester) async {
    Config.set('magic_starter.features.notifications', true);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(
      navRowFor(tester, MagicStarterConfig.notificationPreferencesRoute()),
      isNotNull,
    );
  });

  testWidgets('Notifications row is hidden when notifications feature is off',
      (tester) async {
    Config.set('magic_starter.features.notifications', false);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(
      navRowFor(tester, MagicStarterConfig.notificationPreferencesRoute()),
      isNull,
    );
  });

  testWidgets('Language row appears only when extended-profile feature is on',
      (tester) async {
    Config.set('magic_starter.features.extended_profile', true);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(
      navRowFor(tester, MagicStarterConfig.settingsLanguageRoute()),
      isNotNull,
    );
  });

  testWidgets('Timezone row appears only when timezones feature is on',
      (tester) async {
    Config.set('magic_starter.features.timezones', true);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(
      navRowFor(tester, MagicStarterConfig.settingsTimezoneRoute()),
      isNotNull,
    );
  });

  testWidgets('Newsletter row appears only when newsletter feature is on',
      (tester) async {
    Config.set('magic_starter.features.newsletter', true);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(
      navRowFor(tester, MagicStarterConfig.settingsNewsletterRoute()),
      isNotNull,
    );
  });

  // -------------------------------------------------------------------------
  // Empty-section omission — a section with zero enabled rows must not render
  // -------------------------------------------------------------------------

  testWidgets('Security section is omitted entirely when all its features off',
      (tester) async {
    Config.set('magic_starter.features.two_factor', false);
    Config.set('magic_starter.features.sessions', false);
    // Password change is gated by the ability alone; deny it so the whole
    // Security group has zero rows and must not render.
    Gate.flush();
    Gate.define('starter.delete-account', (user, [_]) => true);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    // No security rows of any kind.
    expect(
        navRowFor(tester, MagicStarterConfig.settingsTwoFactorRoute()), isNull);
    expect(
        navRowFor(tester, MagicStarterConfig.settingsPasswordRoute()), isNull);
    expect(
        navRowFor(tester, MagicStarterConfig.settingsSessionsRoute()), isNull);
  });

  // -------------------------------------------------------------------------
  // Guest upgrade row — only when the user is a guest
  // -------------------------------------------------------------------------

  testWidgets('Guest upgrade row is hidden for a non-guest user',
      (tester) async {
    Gate.define('starter.delete-account', (user, [_]) => true);

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(
      navRowFor(tester, MagicStarterConfig.profileRoute()),
      isNotNull,
    );
    // The guest upgrade row would point at the profile route's upgrade flow;
    // for a non-guest there is exactly one Account row (Profile).
    final accountRows = tester
        .widgetList<SettingsNavRow>(find.byType(SettingsNavRow))
        .where((r) => r.to == MagicStarterConfig.profileRoute());
    expect(accountRows.length, 1);
  });

  // -------------------------------------------------------------------------
  // Slot hooks
  // -------------------------------------------------------------------------

  testWidgets('renders the registered header slot above the sections',
      (tester) async {
    MagicStarter.view.slot(
      'settings.hub',
      'header',
      (context) => const WText('INJECTED HEADER', className: 'text-fg'),
    );

    await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

    expect(find.text('INJECTED HEADER'), findsOneWidget);
  });
}
