import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/facades/magic_starter.dart';
import 'package:magic_starter/src/magic_starter_manager.dart';
import 'package:magic_starter/src/ui/components/page_container/page_container.dart';
import 'package:magic_starter/src/ui/components/page_container/page_container.preview.dart';
import 'package:magic_starter/src/ui/components/page_container/page_container.recipe.dart';

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
        child: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Recipe assertions (pure unit tests, no widget pump required)
  // -------------------------------------------------------------------------

  group('pageContainerRecipe', () {
    test('emits the w-full and mx-auto centering base', () {
      final cls = pageContainerRecipe(
        hostClassName: MagicStarterManager.defaultPageContainerClassName,
      );

      expect(cls, contains('w-full'));
      expect(cls, contains('mx-auto'));
    });

    test('emits the host className so the host owns width and padding', () {
      final cls = pageContainerRecipe(
        hostClassName: 'max-w-6xl px-4 sm:px-5 lg:px-8 pt-6 sm:pt-8 pb-24',
      );

      expect(cls, contains('max-w-6xl'));
      expect(cls, contains('sm:px-5'));
      expect(cls, contains('pb-24'));
      expect(cls, isNot(contains('max-w-7xl')));
    });

    test('appends the caller className after the host className', () {
      final cls = pageContainerRecipe(
        hostClassName: 'max-w-6xl pb-24',
        className: 'pb-4',
      );

      expect(cls.indexOf('pb-4'), greaterThan(cls.indexOf('pb-24')));
    });

    test('omits a null caller className rather than emitting a gap', () {
      final cls = pageContainerRecipe(hostClassName: 'max-w-6xl');

      expect(cls.trim(), cls);
      expect(cls, isNot(contains('  ')));
    });
  });

  // -------------------------------------------------------------------------
  // Widget assertions
  // -------------------------------------------------------------------------

  group('MSPageContainer', () {
    testWidgets('renders a single child', (tester) async {
      await tester.pumpWidget(
        wrap(const MSPageContainer(child: Text('page body'))),
      );

      expect(find.text('page body'), findsOneWidget);
    });

    testWidgets('renders a children list', (tester) async {
      await tester.pumpWidget(
        wrap(
          const MSPageContainer(
            children: [
              Text('header'),
              Text('section'),
            ],
          ),
        ),
      );

      expect(find.text('header'), findsOneWidget);
      expect(find.text('section'), findsOneWidget);
    });

    testWidgets('takes its width and padding from the host manager', (
      tester,
    ) async {
      MagicStarter.manager.pageContainerClassName =
          'max-w-6xl px-4 sm:px-5 lg:px-8 pt-6 sm:pt-8 pb-24';

      await tester.pumpWidget(
        wrap(const MSPageContainer(child: Text('page body'))),
      );

      final container = tester.widget<WDiv>(
        find
            .descendant(
              of: find.byType(MSPageContainer),
              matching: find.byType(WDiv),
            )
            .first,
      );
      expect(container.className, contains('max-w-6xl'));
      expect(container.className, contains('pb-24'));
    });

    testWidgets('guards the horizontal safe area, never the top or bottom', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MSPageContainer(child: Text('page body'))),
      );

      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea).first);
      expect(safeArea.top, isFalse);
      expect(safeArea.bottom, isFalse);
      expect(safeArea.left, isTrue);
      expect(safeArea.right, isTrue);
    });

    testWidgets('preview renders without throwing', (tester) async {
      await tester.pumpWidget(wrap(const PageContainerPreview()));

      expect(find.byType(MSPageContainer), findsWidgets);
    });
  });
}
