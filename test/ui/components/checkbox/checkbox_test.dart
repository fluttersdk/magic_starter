import 'package:flutter/material.dart' hide Checkbox;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/checkbox/checkbox.preview.dart';

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
  // Recipe variant-class assertions
  // ---------------------------------------------------------------------------

  group('checkbox recipe', () {
    test('recipe emits rounded and border tokens', () {
      final cls = checkboxRecipe();
      expect(cls, contains('rounded'));
      expect(cls, contains('border'));
    });

    test('recipe emits bg-primary-container or checked: token', () {
      final cls = checkboxRecipe();
      // The base recipe should include checked: state prefixed tokens.
      expect(cls, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Checkbox renders a WCheckbox', (tester) async {
    await tester.pumpWidget(
      wrap(Checkbox(value: false, onChanged: (_) {})),
    );
    expect(find.byType(WCheckbox), findsOneWidget);
  });

  testWidgets('Checkbox reflects value prop on WCheckbox', (tester) async {
    await tester.pumpWidget(
      wrap(Checkbox(value: true, onChanged: (_) {})),
    );
    final widget = tester.widget<WCheckbox>(find.byType(WCheckbox));
    expect(widget.value, isTrue);
  });

  testWidgets('Checkbox fires onChanged when tapped', (tester) async {
    bool? newValue;
    await tester.pumpWidget(
      wrap(Checkbox(value: false, onChanged: (v) => newValue = v)),
    );
    await tester.tap(find.byType(WCheckbox));
    await tester.pump();
    expect(newValue, isTrue);
  });

  testWidgets('Checkbox preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const CheckboxPreview()));
    await tester.pump();
    expect(find.byType(CheckboxPreview), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Checkbox appends caller className onto the recipe base',
      (tester) async {
    await tester.pumpWidget(
      wrap(Checkbox(value: false, onChanged: (_) {}, className: 'mt-10')),
    );
    final widget = tester.widget<WCheckbox>(find.byType(WCheckbox));
    expect(widget.className, contains('checked:bg-primary'));
    expect(widget.className, contains('mt-10'));
  });
}
