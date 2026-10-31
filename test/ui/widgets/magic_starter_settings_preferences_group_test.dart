import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

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

  /// Turns on every Preferences feature.
  void enableEverything() {
    Config.set('magic_starter.features.notifications', true);
    Config.set('magic_starter.features.extended_profile', true);
    Config.set('magic_starter.features.timezones', true);
    Config.set('magic_starter.features.newsletter', true);
    Config.set('magic_starter.features.releases', true);
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
      }),
    );
    Gate.flush();
    Gate.define('starter.manage-newsletter', (user, [_]) => true);
    Gate.define('starter.delete-account', (user, [_]) => true);
  });

  tearDown(() {
    Gate.flush();
    Auth.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('MagicStarterSettingsPreferencesGroup', () {
    testWidgets('renders every row in the hub order, under its header', (
      tester,
    ) async {
      enableEverything();

      await tester.pumpWidget(
        wrap(const MagicStarterSettingsPreferencesGroup()),
      );

      expect(routes(tester), [
        MagicStarterConfig.settingsAppearanceRoute(),
        MagicStarterConfig.notificationPreferencesRoute(),
        MagicStarterConfig.settingsLanguageRoute(),
        MagicStarterConfig.settingsTimezoneRoute(),
        MagicStarterConfig.settingsNewsletterRoute(),
        MagicStarterConfig.settingsChangelogRoute(),
      ]);
      expect(
        tester.widget<MSSettingsSection>(find.byType(MSSettingsSection)).header,
        trans('magic_starter.settings.preferences_section'),
      );
    });

    testWidgets('keeps Appearance alone with every feature off', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MagicStarterSettingsPreferencesGroup()),
      );

      expect(routes(tester), [MagicStarterConfig.settingsAppearanceRoute()]);
    });

    final Map<String, String Function()> featureRows =
        <String, String Function()>{
          'notifications': MagicStarterConfig.notificationPreferencesRoute,
          'extended_profile': MagicStarterConfig.settingsLanguageRoute,
          'timezones': MagicStarterConfig.settingsTimezoneRoute,
          'newsletter': MagicStarterConfig.settingsNewsletterRoute,
          'releases': MagicStarterConfig.settingsChangelogRoute,
        };

    for (final MapEntry<String, String Function()> entry
        in featureRows.entries) {
      testWidgets('drops its row when ${entry.key} is off', (tester) async {
        enableEverything();
        Config.set('magic_starter.features.${entry.key}', false);

        await tester.pumpWidget(
          wrap(const MagicStarterSettingsPreferencesGroup()),
        );

        expect(routes(tester), isNot(contains(entry.value())));
      });
    }

    testWidgets('Newsletter needs the manage-newsletter ability', (
      tester,
    ) async {
      enableEverything();
      Gate.define('starter.manage-newsletter', (user, [_]) => false);

      await tester.pumpWidget(
        wrap(const MagicStarterSettingsPreferencesGroup()),
      );

      expect(
        routes(tester),
        isNot(contains(MagicStarterConfig.settingsNewsletterRoute())),
      );
    });

    testWidgets('carries no version caption of its own', (tester) async {
      enableEverything();

      await tester.pumpWidget(
        wrap(const MagicStarterSettingsPreferencesGroup()),
      );

      expect(find.byType(MagicStarterAppVersion), findsNothing);
    });
  });
}
