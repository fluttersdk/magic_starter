import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    Widget view = const MagicStarterTeamInvitationAcceptView(),
    Widget Function(Widget child)? frame,
  }) async {
    MagicRoute.page('/invitations/:token/accept', () => view);
    MagicRouter.instance.setInitialLocation('/invitations/tok1/accept');

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: MagicRouter.instance.routerConfig,
        builder: (context, child) => WindTheme(
          data: WindThemeData(),
          child: frame == null
              ? Scaffold(body: SingleChildScrollView(child: child))
              : frame(child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('MagicStarterTeamInvitationAcceptView — slot injection', () {
    late MagicStarterTeamController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      MagicRouter.reset();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Config.set('magic_starter.features.teams', true);
      controller = MagicStarterTeamController.instance;
    });

    tearDown(() {
      controller.members.dispose();
      controller.invitations.dispose();
      controller.currentTeamId.dispose();
      MagicRouter.reset();
    });

    testWidgets('renders header slot when registered', (tester) async {
      MagicStarter.view.slot(
        'teams.invitation_accept',
        'header',
        (ctx) => const Text('Custom Header'),
      );

      await mount(tester);

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('renders footer slot when registered', (tester) async {
      MagicStarter.view.slot(
        'teams.invitation_accept',
        'footer',
        (ctx) => const Text('Custom Footer'),
      );

      await mount(tester);

      expect(find.text('Custom Footer'), findsOneWidget);
    });
  });

  group('MagicStarterTeamInvitationAcceptView — a short viewport', () {
    late MagicStarterTeamController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      MagicRouter.reset();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Config.set('magic_starter.features.teams', true);
      controller = MagicStarterTeamController.instance;
    });

    tearDown(() {
      controller.members.dispose();
      controller.invitations.dispose();
      controller.currentTeamId.dispose();
      MagicRouter.reset();
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

      await mount(tester, frame: (child) => Scaffold(body: child));

      expect(tester.takeException(), isNull);
    });
  });

  group('MagicStarterTeamInvitationAcceptView — the invitation token', () {
    late MagicStarterTeamController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      MagicRouter.reset();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Config.set('magic_starter.features.teams', true);
      controller = MagicStarterTeamController.instance;
    });

    tearDown(() {
      Http.unfake();
      controller.members.dispose();
      controller.invitations.dispose();
      controller.currentTeamId.dispose();
      MagicRouter.reset();
    });

    testWidgets('accepts the token of its own route across two shells', (
      tester,
    ) async {
      // The invitation route is not stacked, so a push over a page in another
      // shell makes the router build the page underneath after this one; a read
      // of the router's last-built state named that page's token.
      final List<String> posted = <String>[];
      Http.fake((request) {
        posted.add('${request.method} ${request.url}');

        return Http.response(<String, dynamic>{});
      });

      MagicRoute.group(
        layout: (child) => Column(children: [Expanded(child: child)]),
        routes: () {
          MagicRoute.page('/elsewhere/:token', () => const Text('Elsewhere'));
        },
      );
      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => Column(children: [Expanded(child: child)]),
        routes: () {
          MagicRoute.page(
            '/invitations/:token/accept',
            () => const MagicStarterTeamInvitationAcceptView(),
          );
        },
      );
      MagicRouter.instance.setInitialLocation('/elsewhere/tok1');
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: MagicRouter.instance.routerConfig,
          builder: (context, child) =>
              WindTheme(data: WindThemeData(), child: child!),
        ),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.routerConfig.push('/invitations/tok2/accept');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(WButton));
      await tester.pumpAndSettle();

      expect(posted, contains('POST /invitations/tok2/accept'));
      expect(posted, isNot(contains('POST /invitations/tok1/accept')));
    });
  });
}
