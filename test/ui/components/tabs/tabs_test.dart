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

  group('tabs recipe', () {
    test('list slot contains border-b', () {
      final cls = tabsRecipe();
      expect(cls['list'], contains('border-b'));
    });

    test('tab slot contains px-', () {
      final cls = tabsRecipe();
      expect(cls['tab'], contains('px-'));
    });

    test('panel slot is non-empty', () {
      final cls = tabsRecipe();
      expect(cls['panel'], isNotEmpty);
    });

    test('all three required slots are present', () {
      final cls = tabsRecipe();
      expect(cls.keys, containsAll(['list', 'tab', 'panel']));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget interaction tests
  // ---------------------------------------------------------------------------

  group('Tabs widget', () {
    testWidgets('renders first panel by default', (tester) async {
      await tester.pumpWidget(
        wrap(
          MSTabs(
            tabs: const ['Tab 1', 'Tab 2'],
            selectedIndex: 0,
            onChanged: (_) {},
            panelBuilder: (i) =>
                i == 0 ? const Text('Panel 1') : const Text('Panel 2'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Panel 1'), findsOneWidget);
      expect(find.text('Panel 2'), findsNothing);
    });

    testWidgets(
        'the selected tab does not underline itself in the rule '
        'colour', (tester) async {
      // The indicator used `border-color-border`, the same token as the rule
      // the tab list sits on, so a selected tab marked itself with a thicker
      // length of the very line under it and read as a grey smudge. Asserted on
      // the rendered colours rather than the className: the className was
      // perfectly valid, it just resolved to the background it was drawn over.
      await tester.pumpWidget(
        wrap(
          MSTabs(
            tabs: const ['Tab 1', 'Tab 2'],
            selectedIndex: 0,
            onChanged: (_) {},
            panelBuilder: (i) => Text('Panel $i'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Set<Color> bottomBorders = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => (decoration.border?.bottom.width ?? 0) > 0)
          .map((decoration) => decoration.border!.bottom.color)
          .toSet();

      expect(
        bottomBorders.length,
        greaterThan(1),
        reason: 'the active indicator and the list rule cannot be the same '
            'colour, or the selection is invisible',
      );
    });

    testWidgets('calls onChanged when a tab is tapped', (tester) async {
      int? changed;
      await tester.pumpWidget(
        wrap(
          MSTabs(
            tabs: const ['Tab 1', 'Tab 2'],
            selectedIndex: 0,
            onChanged: (i) => changed = i,
            panelBuilder: (i) => Text('Panel $i'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tab 2'));
      await tester.pumpAndSettle();

      expect(changed, equals(1));
    });

    testWidgets('renders second panel when selectedIndex is 1', (tester) async {
      await tester.pumpWidget(
        wrap(
          MSTabs(
            tabs: const ['Tab 1', 'Tab 2'],
            selectedIndex: 1,
            onChanged: (_) {},
            panelBuilder: (i) =>
                i == 0 ? const Text('Panel 1') : const Text('Panel 2'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Panel 2'), findsOneWidget);
      expect(find.text('Panel 1'), findsNothing);
    });
  });
}
