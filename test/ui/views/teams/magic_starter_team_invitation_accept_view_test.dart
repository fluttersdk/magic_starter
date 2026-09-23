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

  group('MagicStarterTeamInvitationAcceptView — slot injection', () {
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
        'teams.invitation_accept',
        'header',
        (ctx) => const Text('Custom Header'),
      );

      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('renders footer slot when registered', (tester) async {
      MagicStarter.view.slot(
        'teams.invitation_accept',
        'footer',
        (ctx) => const Text('Custom Footer'),
      );

      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Footer'), findsOneWidget);
    });
  });

  group('MagicStarterTeamInvitationAcceptView — a short viewport', () {
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

    testWidgets('scrolls itself instead of overflowing a bounded height', (
      tester,
    ) async {
      // The only starter screen in the app shell with no scroll of its own. A
      // host whose content box does not scroll (`flex-1 min-h-0`, which every
      // app with a stacked route needs) hands it a bounded height, and a
      // landscape phone makes that height short.
      await tester.binding.setSurfaceSize(const Size(390, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: const Scaffold(body: MagicStarterTeamInvitationAcceptView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
