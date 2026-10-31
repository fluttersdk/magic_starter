import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    MagicStarter.useHostPageChrome((BuildContext context) => true);
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

  Finder headersOfSize(MSPageHeaderSize size) {
    return find.byWidgetPredicate(
      (Widget w) => w is MSPageHeader && w.size == size,
    );
  }

  testWidgets('a large title under host chrome has no frame and no bar', (
    tester,
  ) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(
        MSPageScaffold(
          title: 'Notifications',
          subtitle: 'Recent activity',
          largeTitle: true,
          scrollController: controller,
          actions: const [
            SizedBox(key: Key('mark-all'), width: 40, height: 20),
          ],
          children: const [SizedBox(height: 3000)],
        ),
      ),
    );
    await tester.pump();

    expect(headersOfSize(MSPageHeaderSize.large), findsNothing);
    expect(headersOfSize(MSPageHeaderSize.compact), findsNothing);
    expect(headersOfSize(MSPageHeaderSize.regular), findsOneWidget);
    expect(find.text('Notifications'), findsNothing);
    expect(find.byKey(const Key('mark-all')), findsOneWidget);

    // Scrolled far past where the header was: still no compact bar.
    controller.jumpTo(1500);
    await tester.pumpAndSettle();

    expect(headersOfSize(MSPageHeaderSize.compact), findsNothing);
    expect(find.text('Notifications'), findsNothing);
    expect(MagicStarter.pageChrome.current?.title, 'Notifications');
  });

  testWidgets('the theme large title is skipped the same way', (tester) async {
    MagicStarter.usePageHeaderTheme(
      const MagicStarterPageHeaderTheme(largeTitle: true),
    );

    await tester.pumpWidget(
      wrap(
        const MSPageScaffold(
          title: 'Profile',
          children: [SizedBox(height: 20)],
        ),
      ),
    );

    expect(headersOfSize(MSPageHeaderSize.large), findsNothing);
    expect(headersOfSize(MSPageHeaderSize.regular), findsOneWidget);
  });
}
