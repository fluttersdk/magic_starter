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

  group('combobox recipe', () {
    test('trigger slot contains bg-surface-container-high', () {
      final cls = comboboxRecipe();
      expect(cls['trigger'], contains('bg-surface-container-high'));
    });

    test('popup slot contains bg-surface', () {
      final cls = comboboxRecipe();
      expect(cls['popup'], contains('bg-surface'));
    });

    test('item slot is non-empty', () {
      final cls = comboboxRecipe();
      expect(cls['item'], isNotEmpty);
    });

    test('all three required slots are present', () {
      final cls = comboboxRecipe();
      expect(cls.keys, containsAll(['trigger', 'popup', 'item']));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget interaction tests
  // ---------------------------------------------------------------------------

  group('Combobox widget', () {
    testWidgets('renders WSelect with searchable=true', (tester) async {
      await tester.pumpWidget(
        wrap(
          Combobox<String>(
            value: null,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final select = tester.widget<WSelect<String>>(
        find.byType(WSelect<String>),
      );
      expect(select.searchable, isTrue);
    });
  });
}
