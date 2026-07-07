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

  // ---------------------------------------------------------------------------
  // Recipe slot-class assertions
  // ---------------------------------------------------------------------------

  group('accordion recipe', () {
    test('root slot is non-empty', () {
      final cls = accordionRecipe();
      expect(cls['root'], isNotEmpty);
    });

    test('item slot is non-empty', () {
      final cls = accordionRecipe();
      expect(cls['item'], isNotEmpty);
    });

    test('header slot is non-empty', () {
      final cls = accordionRecipe();
      expect(cls['header'], isNotEmpty);
    });

    test('trigger slot is non-empty', () {
      final cls = accordionRecipe();
      expect(cls['trigger'], isNotEmpty);
    });

    test('panel slot is non-empty', () {
      final cls = accordionRecipe();
      expect(cls['panel'], isNotEmpty);
    });

    test('all five required slots are present', () {
      final cls = accordionRecipe();
      expect(
        cls.keys,
        containsAll(['root', 'item', 'header', 'trigger', 'panel']),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Widget interaction tests
  // ---------------------------------------------------------------------------

  group('Accordion widget', () {
    testWidgets('renders item titles', (tester) async {
      await tester.pumpWidget(
        wrap(
          MSAccordion(
            items: const [
              MSAccordionItem(title: 'Section 1', body: Text('Content 1')),
              MSAccordionItem(title: 'Section 2', body: Text('Content 2')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Section 1'), findsOneWidget);
      expect(find.text('Section 2'), findsOneWidget);
    });

    testWidgets('content is hidden by default (collapsed)', (tester) async {
      await tester.pumpWidget(
        wrap(
          MSAccordion(
            items: const [
              MSAccordionItem(title: 'Section 1', body: Text('Content 1')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Content 1'), findsNothing);
    });

    testWidgets('tapping header expands the panel', (tester) async {
      await tester.pumpWidget(
        wrap(
          MSAccordion(
            items: const [
              MSAccordionItem(title: 'Section 1', body: Text('Content 1')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();

      expect(find.text('Content 1'), findsOneWidget);
    });

    testWidgets('tapping expanded header collapses the panel', (tester) async {
      await tester.pumpWidget(
        wrap(
          MSAccordion(
            items: const [
              MSAccordionItem(title: 'Section 1', body: Text('Content 1')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand.
      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();
      expect(find.text('Content 1'), findsOneWidget);

      // Collapse.
      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();
      expect(find.text('Content 1'), findsNothing);
    });
  });
}
