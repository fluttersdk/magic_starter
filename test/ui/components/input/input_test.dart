import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/input/input.preview.dart';

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

  group('input recipe', () {
    test('default state emits bg-surface-container-high token', () {
      final cls = inputRecipe(
        variants: {'state': InputState.normal.name},
      );
      expect(cls, contains('bg-surface-container-high'));
    });

    test('error state emits border-destructive or similar error token', () {
      final cls = inputRecipe(
        variants: {'state': InputState.error.name},
      );
      // Error state should apply error styling class
      expect(cls, contains('border'));
    });

    test('default variant produces normal state when nothing is passed', () {
      final cls = inputRecipe();
      expect(cls, contains('bg-surface-container-high'));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Input renders a WInput or WFormInput widget', (tester) async {
    await tester.pumpWidget(
      wrap(const Input(placeholder: 'Enter text')),
    );
    // Input wraps WInput
    expect(find.byType(WInput), findsOneWidget);
  });

  testWidgets('Input applies bg-surface-container-high in normal state',
      (tester) async {
    await tester.pumpWidget(
      wrap(const Input(placeholder: 'Enter text')),
    );
    final widget = tester.widget<WInput>(find.byType(WInput));
    expect(widget.className, contains('bg-surface-container-high'));
  });

  testWidgets('Input preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const InputPreview()));
    await tester.pump();
    expect(find.byType(InputPreview), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Input appends caller className onto the recipe base',
      (tester) async {
    await tester.pumpWidget(
      wrap(const Input(placeholder: 'x', className: 'mt-10')),
    );
    final widget = tester.widget<WInput>(find.byType(WInput));
    expect(widget.className, contains('bg-surface-container-high'));
    expect(widget.className, contains('mt-10'));
  });

  // ---------------------------------------------------------------------------
  // fullWidth prop (MS-2)
  // ---------------------------------------------------------------------------

  testWidgets(
      'Input(fullWidth: true) wraps the WInput in a SizedBox(width: infinity) '
      'and keeps intent styling', (tester) async {
    await tester.pumpWidget(
      wrap(const Input(fullWidth: true, placeholder: 'Enter text')),
    );

    final fullWidthWrapper = find.ancestor(
      of: find.byType(WInput),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == double.infinity,
      ),
    );
    expect(fullWidthWrapper, findsOneWidget);

    final widget = tester.widget<WInput>(find.byType(WInput));
    expect(widget.className, contains('bg-surface-container-high'));
  });

  testWidgets('Input fullWidth defaults to false (no SizedBox wrapper)',
      (tester) async {
    await tester.pumpWidget(
      wrap(const Input(placeholder: 'Hi')),
    );

    final fullWidthWrapper = find.ancestor(
      of: find.byType(WInput),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == double.infinity,
      ),
    );
    expect(fullWidthWrapper, findsNothing);
  });
}
