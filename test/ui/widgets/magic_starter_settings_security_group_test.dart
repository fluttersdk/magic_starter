import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// A bridge the group only needs to see as present.
class _SilentSocialAuth implements MagicStarterSocialAuth {
  @override
  List<String> providers() => const ['google'];

  @override
  String label(String provider) => 'Google';

  @override
  Widget icon(String provider) => const SizedBox();

  @override
  Future<Map<String, dynamic>> signIn(String provider) =>
      throw UnimplementedError();

  @override
  Future<Future<Map<String, dynamic>> Function()> beginConnect(
    String provider,
    Map<String, String> proof,
  ) => throw UnimplementedError();

  @override
  Future<String> confirm(String provider) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: widget),
      ),
    );
  }

  List<String> routes(WidgetTester tester) {
    return tester
        .widgetList<MSSettingsNavRow>(find.byType(MSSettingsNavRow))
        .map((row) => row.to)
        .toList();
  }

  /// Turns on every Security feature and grants every Security ability.
  void enableEverything() {
    Config.set('magic_starter.features.two_factor', true);
    Config.set('magic_starter.features.sessions', true);
    Config.set('magic_starter.features.social_login', true);
    MagicStarter.useSocialAuth(_SilentSocialAuth());
  }

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    setUpMagicStarterForTests();
    Auth.fake(
      user: MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Test User',
        'email': 'test@example.com',
        'two_factor_enabled': true,
      }),
    );
    Gate.flush();
    Gate.define('starter.update-password', (user, [_]) => true);
    Gate.define('starter.manage-two-factor', (user, [_]) => true);
    Gate.define('starter.delete-account', (user, [_]) => true);
  });

  tearDown(() {
    Gate.flush();
    Auth.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('MagicStarterSettingsSecurityGroup', () {
    testWidgets('renders every row in the hub order, under its header', (
      tester,
    ) async {
      enableEverything();

      await tester.pumpWidget(wrap(const MagicStarterSettingsSecurityGroup()));

      expect(routes(tester), [
        MagicStarterConfig.settingsTwoFactorRoute(),
        MagicStarterConfig.settingsPasswordRoute(),
        MagicStarterConfig.settingsSessionsRoute(),
        MagicStarterConfig.settingsConnectedAccountsRoute(),
      ]);
      expect(
        tester
            .widgetList<MSSettingsNavRow>(find.byType(MSSettingsNavRow))
            .first
            .value,
        trans('common.on'),
      );
      expect(
        tester.widget<MSSettingsSection>(find.byType(MSSettingsSection)).header,
        trans('magic_starter.settings.security_section'),
      );
    });

    testWidgets('Two-factor needs the feature', (tester) async {
      enableEverything();
      Config.set('magic_starter.features.two_factor', false);

      await tester.pumpWidget(wrap(const MagicStarterSettingsSecurityGroup()));

      expect(
        routes(tester),
        isNot(contains(MagicStarterConfig.settingsTwoFactorRoute())),
      );
    });

    testWidgets('Two-factor needs the manage-two-factor ability', (
      tester,
    ) async {
      enableEverything();
      Gate.define('starter.manage-two-factor', (user, [_]) => false);

      await tester.pumpWidget(wrap(const MagicStarterSettingsSecurityGroup()));

      expect(
        routes(tester),
        isNot(contains(MagicStarterConfig.settingsTwoFactorRoute())),
      );
    });

    testWidgets('Password needs the update-password ability', (tester) async {
      enableEverything();
      Gate.define('starter.update-password', (user, [_]) => false);

      await tester.pumpWidget(wrap(const MagicStarterSettingsSecurityGroup()));

      expect(
        routes(tester),
        isNot(contains(MagicStarterConfig.settingsPasswordRoute())),
      );
    });

    testWidgets('Sessions needs the feature', (tester) async {
      enableEverything();
      Config.set('magic_starter.features.sessions', false);

      await tester.pumpWidget(wrap(const MagicStarterSettingsSecurityGroup()));

      expect(
        routes(tester),
        isNot(contains(MagicStarterConfig.settingsSessionsRoute())),
      );
    });

    testWidgets('Connected accounts needs a social auth bridge', (
      tester,
    ) async {
      Config.set('magic_starter.features.social_login', true);

      await tester.pumpWidget(wrap(const MagicStarterSettingsSecurityGroup()));

      expect(
        routes(tester),
        isNot(contains(MagicStarterConfig.settingsConnectedAccountsRoute())),
      );
    });

    testWidgets('renders nothing, header included, when no row is left', (
      tester,
    ) async {
      Gate.flush();
      Gate.define('starter.delete-account', (user, [_]) => false);

      await tester.pumpWidget(wrap(const MagicStarterSettingsSecurityGroup()));

      expect(MagicStarterSettingsSecurityGroup.hasRows, isFalse);
      expect(find.byType(MSSettingsSection), findsNothing);
      expect(
        tester.getSize(find.byType(MagicStarterSettingsSecurityGroup)),
        Size.zero,
      );
    });

    test('hasRows follows the same gates as the rows', () {
      Gate.flush();
      expect(MagicStarterSettingsSecurityGroup.hasRows, isFalse);

      Gate.define('starter.update-password', (user, [_]) => true);
      expect(MagicStarterSettingsSecurityGroup.hasRows, isTrue);
    });
  });
}
