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
  // Recipe slot-class assertions (TDD: write failing tests first)
  // ---------------------------------------------------------------------------

  group('select recipe', () {
    test('trigger slot contains bg-surface-container-high', () {
      final cls = selectRecipe();
      expect(cls['trigger'], contains('bg-surface-container-high'));
    });

    test('popup slot contains bg-surface', () {
      final cls = selectRecipe();
      expect(cls['popup'], contains('bg-surface'));
    });

    test('item slot is non-empty', () {
      final cls = selectRecipe();
      expect(cls['item'], isNotEmpty);
    });

    test('all three required slots are present', () {
      final cls = selectRecipe();
      expect(cls.keys, containsAll(['trigger', 'popup', 'item']));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget interaction tests
  // ---------------------------------------------------------------------------

  group('Select widget', () {
    testWidgets('renders and shows WSelect', (tester) async {
      await tester.pumpWidget(
        wrap(
          MSSelect<String>(
            value: null,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WSelect<String>), findsOneWidget);
    });

    testWidgets('calls onChange when option is selected', (tester) async {
      String? selected;
      await tester.pumpWidget(
        wrap(
          MSSelect<String>(
            value: null,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (v) => selected = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the trigger to open.
      await tester.tap(find.byType(WSelect<String>));
      await tester.pumpAndSettle();

      // Tap the option.
      await tester.tap(find.text('Option A'));
      await tester.pumpAndSettle();

      expect(selected, equals('a'));
    });
  });
}
