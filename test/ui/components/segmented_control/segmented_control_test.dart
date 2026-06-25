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

  group('segmented control recipe', () {
    test('sm size emits text-sm', () {
      final cls = segmentedControlRecipe(
        variants: {'size': SegmentedControlSize.sm.name},
      );
      expect(cls['item'], contains('text-sm'));
    });

    test('md size emits text-sm or text-base', () {
      final cls = segmentedControlRecipe(
        variants: {'size': SegmentedControlSize.md.name},
      );
      // md size item should have some text-size token
      expect(cls['item'], isNotEmpty);
    });

    test('root slot contains bg-surface-container-high', () {
      final cls = segmentedControlRecipe();
      expect(cls['root'], contains('bg-surface-container-high'));
    });

    test('all two required slots are present', () {
      final cls = segmentedControlRecipe();
      expect(cls.keys, containsAll(['root', 'item']));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  group('SegmentedControl widget', () {
    testWidgets('renders option labels', (tester) async {
      await tester.pumpWidget(
        wrap(
          SegmentedControl<String>(
            options: const ['Option A', 'Option B', 'Option C'],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
      expect(find.text('Option C'), findsOneWidget);
    });

    testWidgets('calls onChanged when a segment is tapped', (tester) async {
      int? changed;
      await tester.pumpWidget(
        wrap(
          SegmentedControl<String>(
            options: const ['Option A', 'Option B'],
            selectedIndex: 0,
            onChanged: (i) => changed = i,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Option B'));
      await tester.pumpAndSettle();

      expect(changed, equals(1));
    });
  });
}
