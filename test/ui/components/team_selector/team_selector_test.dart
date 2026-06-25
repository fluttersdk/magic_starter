import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/team_selector/index.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: widget),
      ),
    );
  }

  testWidgets('TeamSelector returns empty when no resolver registered',
      (tester) async {
    await tester.pumpWidget(wrap(const TeamSelector()));
    await tester.pump();
    // When no resolver, renders SizedBox.shrink
    expect(find.byType(WPopover), findsNothing);
  });

  testWidgets('TeamSelector renders team initial when resolver has teams',
      (tester) async {
    final teams = [
      MagicStarterTeam.fromMap({'id': 1, 'name': 'Acme Corp', 'personal_team': false}),
      MagicStarterTeam.fromMap({'id': 2, 'name': 'Beta Inc', 'personal_team': false}),
    ];
    MagicStarter.useTeamResolver(
      currentTeam: () => teams.first,
      allTeams: () => teams,
      onSwitch: (id) async {},
    );

    await tester.pumpWidget(wrap(const TeamSelector()));
    await tester.pump();

    // The first letter of 'Acme Corp' is shown as the team initial
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('TeamSelector returns empty when teams list is empty',
      (tester) async {
    MagicStarter.useTeamResolver(
      currentTeam: () => null,
      allTeams: () => [],
      onSwitch: (id) async {},
    );

    await tester.pumpWidget(wrap(const TeamSelector()));
    await tester.pump();

    expect(find.byType(WPopover), findsNothing);
  });

  testWidgets('TeamSelector preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const TeamSelectorPreview()));
    await tester.pump();
    expect(find.byType(TeamSelectorPreview), findsOneWidget);
  });
}
