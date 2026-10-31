import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

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

  Finder headings() {
    return find.byWidgetPredicate(
      (Widget w) => w is Semantics && (w.properties.header ?? false),
    );
  }

  const Key actionKey = Key('mark-all-read');

  MSPageHeader header({
    String title = 'Profile',
    MSPageHeaderSize? size,
    List<Widget>? actions,
  }) {
    return MSPageHeader(
      title: title,
      subtitle: 'Your details',
      backLabel: 'Settings',
      backFallback: '/settings',
      titleSuffix: const Text('suffix'),
      subtitleSuffix: const Text('subtitle suffix'),
      size: size,
      actions: actions,
    );
  }

  group('MSPageHeader under host-owned chrome', () {
    setUp(() {
      MagicStarter.useHostPageChrome((BuildContext context) => true);
    });

    for (final MSPageHeaderSize size in MSPageHeaderSize.values) {
      testWidgets('${size.name}: draws only the actions and reports the rest', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            header(
              size: size,
              actions: const [SizedBox(key: actionKey, width: 40, height: 20)],
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(actionKey), findsOneWidget);
        expect(find.text('Profile'), findsNothing);
        expect(find.text('Your details'), findsNothing);
        expect(find.text('suffix'), findsNothing);
        expect(find.text('subtitle suffix'), findsNothing);
        expect(find.byIcon(Icons.chevron_left), findsNothing);
        expect(headings(), findsNothing);

        expect(
          MagicStarter.pageChrome.current,
          const MagicStarterPageChromeEntry(
            title: 'Profile',
            subtitle: 'Your details',
            backLabel: 'Settings',
            backFallback: '/settings',
          ),
        );
      });
    }

    testWidgets('draws nothing at all without actions', (tester) async {
      await tester.pumpWidget(wrap(header()));

      expect(
        find.descendant(
          of: find.byType(MSPageHeader),
          matching: find.byType(WDiv),
        ),
        findsNothing,
      );
    });

    testWidgets('the actions sit at the right edge', (tester) async {
      await tester.pumpWidget(
        wrap(
          header(
            actions: const [SizedBox(key: actionKey, width: 40, height: 20)],
          ),
        ),
      );

      final double right = tester.getTopRight(find.byKey(actionKey)).dx;
      final double edge = tester.getTopRight(find.byType(MSPageHeader)).dx;
      expect(right, edge);
    });

    testWidgets('the entry follows a widget update', (tester) async {
      await tester.pumpWidget(wrap(header()));
      await tester.pump();

      await tester.pumpWidget(wrap(header(title: 'Sessions')));
      await tester.pump();

      expect(MagicStarter.pageChrome.current?.title, 'Sessions');
    });

    testWidgets('the entry is withdrawn on dispose', (tester) async {
      await tester.pumpWidget(wrap(header()));
      await tester.pump();
      expect(MagicStarter.pageChrome.current, isNotNull);

      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      await tester.pump();

      expect(MagicStarter.pageChrome.current, isNull);
    });

    testWidgets('a host bar listening to the chrome builds without a throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              ListenableBuilder(
                listenable: MagicStarter.pageChrome,
                builder: (BuildContext context, Widget? child) => Text(
                  'bar: ${MagicStarter.pageChrome.current?.title ?? '-'}',
                ),
              ),
              header(),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('bar: Profile'), findsOneWidget);
    });
  });

  group('MSPageHeader with a width predicate', () {
    testWidgets('the predicate reads the MediaQuery of the header', (
      tester,
    ) async {
      MagicStarter.useHostPageChrome(
        (BuildContext context) => MediaQuery.sizeOf(context).width < 600,
      );

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(header()));
      await tester.pump();

      expect(find.text('Profile'), findsNothing);
      expect(MagicStarter.pageChrome.current?.title, 'Profile');

      // Wider than the predicate's line: the header draws itself again and
      // hands the chrome back.
      tester.view.physicalSize = const Size(1200, 844);
      await tester.pump();
      await tester.pump();

      expect(find.text('Profile'), findsOneWidget);
      expect(MagicStarter.pageChrome.current, isNull);
    });
  });

  group('MSPageHeader with no predicate registered', () {
    testWidgets('draws itself and reports nothing', (tester) async {
      await tester.pumpWidget(wrap(header()));
      await tester.pump();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(headings(), findsOneWidget);
      expect(MagicStarter.pageChrome.current, isNull);
    });
  });
}
