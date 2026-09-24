import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
  }

  group('MagicStarterTeamCreateView — slot injection', () {
    late MagicStarterTeamController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Config.set('magic_starter.features.teams', true);
      controller = MagicStarterTeamController.instance;
    });

    tearDown(() {
      controller.members.dispose();
      controller.invitations.dispose();
      controller.currentTeamId.dispose();
    });

    testWidgets('renders header slot when registered', (tester) async {
      MagicStarter.view.slot(
        'teams.create',
        'header',
        (ctx) => const Text('Custom Header'),
      );

      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('renders footer slot when registered', (tester) async {
      MagicStarter.view.slot(
        'teams.create',
        'footer',
        (ctx) => const Text('Custom Footer'),
      );

      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      expect(find.text('Custom Footer'), findsOneWidget);
    });
  });

  group('MagicStarterTeamCreateView — opened over team settings', () {
    late MagicStarterTeamController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Config.set('magic_starter.features.teams', true);
      controller = MagicStarterTeamController.instance;
    });

    tearDown(() {
      controller.members.dispose();
      controller.invitations.dispose();
      controller.currentTeamId.dispose();
    });

    testWidgets('settings opened over it does not rebuild it mid-build', (
      tester,
    ) async {
      // After a successful create the view navigates to team settings, which
      // is stacked over it. Settings loads members on mount, and that load
      // set loading before its first await, marking this view dirty while the
      // settings route was being built (#163). A team id is what makes the
      // load run at all.
      Http.fake();
      controller.currentTeamId.value = 1;
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: WindTheme(
            data: WindThemeData(),
            child: const Scaffold(body: MagicStarterTeamCreateView()),
          ),
        ),
      );
      await tester.pump();

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => WindTheme(
            data: WindThemeData(),
            child: const Scaffold(body: MagicStarterTeamSettingsView()),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('does not rebuild the settings view mid-build', (tester) async {
      // The team selector opens create from the settings page, and both bind
      // this controller. A notifying reset in create's onInit marked settings
      // dirty while the create route was being built.
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: WindTheme(
            data: WindThemeData(),
            child: const Scaffold(body: MagicStarterTeamSettingsView()),
          ),
        ),
      );
      await tester.pump();
      controller.setError('stale');

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => WindTheme(
            data: WindThemeData(),
            child: const Scaffold(body: MagicStarterTeamCreateView()),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
