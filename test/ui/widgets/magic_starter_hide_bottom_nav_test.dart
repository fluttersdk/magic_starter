import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Pins the bottom nav to the hiding page's route animation.
///
/// The visibility is read off the slot's rendered height against the bar's
/// natural one, so nothing here reaches into private state. Every route
/// change animates (`RouteTransition.fade`, linear over 300ms), because the
/// claim under test is about the frames between the two settled states: a
/// boolean that flipped at the start of the transition would pass every
/// settled assertion and fail every mid-transition one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();

    Config.set('magic_starter.features.support', true);
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Auth.fake(
      user: MagicStarterAuthUser.fromMap(<String, dynamic>{
        'id': 5,
        'name': 'Ada Lovelace',
      }),
    );
  });

  tearDown(() {
    Kernel.flush();
    Auth.unfake();
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  /// Mounts the starter's own support routes under the default app layout, at
  /// phone width with one bottom destination, and lands on the list.
  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    Kernel.register('auth', AllowAllMiddleware.new);
    MagicStarter.useNavigation(
      mainItems: const [],
      bottomItems: const [
        MagicStarterNavItem(
          icon: Icons.support_agent,
          labelKey: 'Support',
          path: '/support',
        ),
      ],
    );
    MagicStarter.view.register('support.index', () => const Text('list'));
    MagicStarter.view.register('support.create', () => const Text('create'));
    MagicStarter.view.register('support.thread', () => const Text('thread'));

    MagicRouter.instance.defaultTransition = RouteTransition.fade;
    registerMagicStarterSupportRoutes();
    MagicRouter.instance.setInitialLocation(MagicStarterConfig.supportRoute());

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp.router(
          routerConfig: MagicRouter.instance.routerConfig,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double navHeight(WidgetTester tester) {
    return tester.getSize(find.byType(MagicStarterBottomNavSlot)).height;
  }

  /// Pumps 1ms frames until the page showing [text] is in the tree, calling
  /// [eachFrame] after every one.
  ///
  /// The route is in from the frame go_router resolves the location, but the
  /// page is not: magic's middleware guard builds a placeholder and mounts the
  /// page only once its middleware has run, which takes the clock moving.
  Future<void> pumpUntilMounted(
    WidgetTester tester,
    String text, {
    void Function()? eachFrame,
  }) async {
    for (int i = 0; i < 10 && find.text(text).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      eachFrame?.call();
    }

    expect(find.text(text), findsOneWidget);
  }

  State shellState(WidgetTester tester) {
    return tester.state(find.byType(MagicStarterAppLayout));
  }

  group('MagicStarterBottomNavSlot under the app layout', () {
    testWidgets('collapses with the thread push and returns with its pop', (
      WidgetTester tester,
    ) async {
      await mount(tester);

      final double full = navHeight(tester);
      final State shell = shellState(tester);
      expect(full, greaterThan(0));

      // 1. Push: every frame up to the one the page mounts on, the route's
      //    first included, still shows the whole bar.
      MagicRoute.to(MagicStarterConfig.supportThreadPath(7));
      await pumpUntilMounted(
        tester,
        'thread',
        eachFrame: () => expect(navHeight(tester), full),
      );

      // 2. Halfway through, the bar is halfway gone.
      await tester.pump(const Duration(milliseconds: 150));
      expect(navHeight(tester), inExclusiveRange(0, full));

      // 3. Settled on the thread, the bar is gone.
      await tester.pumpAndSettle();
      expect(navHeight(tester), 0);
      expect(identical(shellState(tester), shell), isTrue);

      // 4. Pop: the bar comes back with the page, not at the start.
      MagicRoute.back();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(navHeight(tester), inExclusiveRange(0, full));

      await tester.pumpAndSettle();
      expect(find.text('thread'), findsNothing);
      expect(navHeight(tester), full);
      expect(identical(shellState(tester), shell), isTrue);
    });

    testWidgets('a page pushed over the thread brings the bar back', (
      WidgetTester tester,
    ) async {
      await mount(tester);

      final double full = navHeight(tester);

      MagicRoute.to(MagicStarterConfig.supportThreadPath(7));
      await tester.pumpAndSettle();
      expect(navHeight(tester), 0);

      // The thread stays mounted beneath; its secondary animation is what
      // carries the bar back in.
      MagicRoute.to(MagicStarterConfig.supportCreateRoute());
      await pumpUntilMounted(tester, 'create');
      await tester.pump(const Duration(milliseconds: 150));
      expect(navHeight(tester), inExclusiveRange(0, full));

      await tester.pumpAndSettle();
      expect(navHeight(tester), full);
    });
  });

  group('without a MagicStarterBottomNavScope', () {
    testWidgets('the slot renders its child fully visible', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              Expanded(
                child: MagicStarterHideBottomNav(child: SizedBox.expand()),
              ),
              MagicStarterBottomNavSlot(child: SizedBox(height: 56)),
            ],
          ),
        ),
      );

      expect(navHeight(tester), 56);
      expect(tester.takeException(), isNull);
    });
  });
}
