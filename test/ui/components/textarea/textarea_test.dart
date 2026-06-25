import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/textarea/textarea.preview.dart';

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

  group('textarea recipe', () {
    test('default state emits bg-surface-container-high token', () {
      final cls = textareaRecipe(
        variants: {'state': TextareaState.normal.name},
      );
      expect(cls, contains('bg-surface-container-high'));
    });

    test('error state emits error-related styling', () {
      final cls = textareaRecipe(
        variants: {'state': TextareaState.error.name},
      );
      expect(cls, contains('border'));
    });

    test('default variant produces normal state when nothing is passed', () {
      final cls = textareaRecipe();
      expect(cls, contains('bg-surface-container-high'));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Textarea renders a WInput widget in multiline mode',
      (tester) async {
    await tester.pumpWidget(
      wrap(const Textarea(placeholder: 'Enter text')),
    );
    expect(find.byType(WInput), findsOneWidget);
  });

  testWidgets('Textarea applies bg-surface-container-high in normal state',
      (tester) async {
    await tester.pumpWidget(
      wrap(const Textarea(placeholder: 'Enter text')),
    );
    final widget = tester.widget<WInput>(find.byType(WInput));
    expect(widget.className, contains('bg-surface-container-high'));
  });

  testWidgets('Textarea preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const TextareaPreview()));
    await tester.pump();
    expect(find.byType(TextareaPreview), findsOneWidget);
  });
}
