import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

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
}
