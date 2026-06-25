import 'package:flutter/material.dart' hide Radio;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/radio/radio.preview.dart';

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

  group('radio recipe', () {
    test('shell recipe emits rounded-full token', () {
      final cls = radioShellRecipe();
      expect(cls, contains('rounded-full'));
    });

    test('shell recipe emits border token', () {
      final cls = radioShellRecipe();
      expect(cls, contains('border'));
    });

    test('shell recipe includes selected: state prefix for primary color', () {
      final cls = radioShellRecipe();
      expect(cls, contains('selected:border-color-border'));
    });

    test('indicator recipe emits bg-primary token', () {
      final cls = radioIndicatorRecipe();
      expect(cls, contains('bg-primary'));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Radio renders a WRadio widget', (tester) async {
    await tester.pumpWidget(
      wrap(
        Radio<String>(
          value: 'a',
          groupValue: 'a',
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.byType(WRadio<String>), findsOneWidget);
  });

  testWidgets('Radio reflects selected state when value == groupValue',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Radio<String>(
          value: 'a',
          groupValue: 'a',
          onChanged: (_) {},
        ),
      ),
    );
    final widget = tester.widget<WRadio<String>>(find.byType(WRadio<String>));
    expect(widget.value, equals(widget.groupValue));
  });

  testWidgets('Radio fires onChanged when tapped while not selected',
      (tester) async {
    String? selected;
    await tester.pumpWidget(
      wrap(
        Radio<String>(
          value: 'b',
          groupValue: 'a',
          onChanged: (v) => selected = v,
        ),
      ),
    );
    await tester.tap(find.byType(WRadio<String>));
    await tester.pump();
    expect(selected, equals('b'));
  });

  testWidgets('Radio preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const RadioPreview()));
    await tester.pump();
    expect(find.byType(RadioPreview), findsOneWidget);
  });
}
