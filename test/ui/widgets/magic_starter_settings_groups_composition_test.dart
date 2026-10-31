import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/views/settings/magic_starter_settings_hub_view.dart';

/// The page a host composes from the three groups beside its own section.
class _HostSettingsPage extends StatelessWidget {
  const _HostSettingsPage();

  @override
  Widget build(BuildContext context) {
    return MSPageScaffold(
      title: 'Settings',
      children: [
        const MSSettingsSection(
          header: 'Playback',
          children: [MSSettingsNavRow(title: 'Player', to: '/settings/player')],
        ),
        const MagicStarterSettingsAccountGroup(),
        if (MagicStarterSettingsSecurityGroup.hasRows)
          const MagicStarterSettingsSecurityGroup(),
        const MagicStarterSettingsPreferencesGroup(),
      ],
    );
  }
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

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    setUpMagicStarterForTests();
    Magic.put(MagicStarterProfileController());
    Auth.fake(
      user: MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Test User',
        'email': 'test@example.com',
      }),
    );
    Gate.flush();
    Gate.define('starter.update-password', (user, [_]) => true);
    Gate.define('starter.delete-account', (user, [_]) => true);
    Config.set('magic_starter.features.sessions', true);
    Config.set('magic_starter.features.timezones', true);
  });

  tearDown(() {
    Gate.flush();
    Auth.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('a host settings page composed from the groups', () {
    testWidgets('links to the routes the hub links to, after the host rows', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));
      final List<String> hubRoutes = routes(tester);

      await tester.pumpWidget(wrap(const _HostSettingsPage()));

      expect(routes(tester), ['/settings/player', ...hubRoutes]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds with no page chrome predicate registered', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const _HostSettingsPage()));

      expect(find.byType(MSSettingsSection), findsNWidgets(4));
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('builds with a page chrome predicate registered', (
      tester,
    ) async {
      MagicStarter.useHostPageChrome((BuildContext context) => true);

      await tester.pumpWidget(wrap(const _HostSettingsPage()));
      await tester.pump();

      expect(find.byType(MSSettingsSection), findsNWidgets(4));
      expect(MagicStarter.pageChrome.current?.title, 'Settings');
      expect(
        routes(tester),
        containsAll(<String>[
          MagicStarterConfig.profileRoute(),
          MagicStarterConfig.settingsPasswordRoute(),
          MagicStarterConfig.settingsAppearanceRoute(),
        ]),
      );
    });
  });

  group('the hub composed from the groups', () {
    testWidgets('mounts the three groups', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

      expect(find.byType(MagicStarterSettingsAccountGroup), findsOneWidget);
      expect(find.byType(MagicStarterSettingsSecurityGroup), findsOneWidget);
      expect(find.byType(MagicStarterSettingsPreferencesGroup), findsOneWidget);
    });

    testWidgets('leaves an empty Security group out of its sections column', (
      tester,
    ) async {
      // A zero-size child still takes a gap in the `gap-6` column, so the hub
      // must not mount the group at all for the page to keep its old spacing.
      Gate.flush();
      Gate.define('starter.delete-account', (user, [_]) => true);
      Config.set('magic_starter.features.sessions', false);

      await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));

      expect(find.byType(MagicStarterSettingsSecurityGroup), findsNothing);
      expect(find.byType(MSSettingsSection), findsNWidgets(2));
    });

    testWidgets('re-reads the user when the hub rebuilds', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterSettingsHubView()));
      expect(find.text('Test User · test@example.com'), findsOneWidget);

      Auth.fake(
        user: MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Renamed',
          'email': 'test@example.com',
        }),
      );
      Magic.find<MagicStarterProfileController>().refreshUI();
      await tester.pump();

      expect(find.text('Renamed · test@example.com'), findsOneWidget);
    });
  });
}
