import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
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
      wrap(const MSTextarea(placeholder: 'Enter text')),
    );
    expect(find.byType(WInput), findsOneWidget);
  });

  testWidgets('Textarea applies bg-surface-container-high in normal state',
      (tester) async {
    await tester.pumpWidget(
      wrap(const MSTextarea(placeholder: 'Enter text')),
    );
    final widget = tester.widget<WInput>(find.byType(WInput));
    expect(widget.className, contains('bg-surface-container-high'));
  });

  testWidgets('Textarea preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const TextareaPreview()));
    await tester.pump();
    expect(find.byType(TextareaPreview), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Textarea appends caller className onto the recipe base',
      (tester) async {
    await tester.pumpWidget(
      wrap(const MSTextarea(placeholder: 'x', className: 'mt-10')),
    );
    final widget = tester.widget<WInput>(find.byType(WInput));
    expect(widget.className, contains('bg-surface-container-high'));
    expect(widget.className, contains('mt-10'));
  });

  // ---------------------------------------------------------------------------
  // fullWidth prop (MS-2)
  // ---------------------------------------------------------------------------

  testWidgets(
      'Textarea(fullWidth: true) wraps the WInput in a SizedBox(width: '
      'infinity) and keeps intent styling', (tester) async {
    await tester.pumpWidget(
      wrap(const MSTextarea(fullWidth: true, placeholder: 'Enter text')),
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

  testWidgets('Textarea fullWidth defaults to false (no SizedBox wrapper)',
      (tester) async {
    await tester.pumpWidget(
      wrap(const MSTextarea(placeholder: 'Hi')),
    );

    final fullWidthWrapper = find.ancestor(
      of: find.byType(WInput),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == double.infinity,
      ),
    );
    expect(fullWidthWrapper, findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Keyboard dismissal
  // ---------------------------------------------------------------------------

  group('keyboard dismissal', () {
    testWidgets('a focused textarea offers a Done button on iOS', (
      tester,
    ) async {
      // Return inserts a newline in a multiline field, so without this the
      // keyboard has no key that closes it: a phone user who tabbed in from the
      // field above was left with an open keyboard over a hidden form.
      // Reset inside the body, not in a tearDown: flutter_test asserts every
      // foundation debug variable is unset BEFORE tearDowns run.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(wrap(const MSTextarea(placeholder: 'Notes')));

        expect(
          find.descendant(
            of: find.byType(Overlay),
            matching: find.byType(TextButton),
          ),
          findsNothing,
          reason: 'the toolbar belongs to a focused field, not to the page',
        );

        await tester.tap(find.byType(MSTextarea));
        await tester.pump(const Duration(milliseconds: 16));

        expect(
          find.descendant(
            of: find.byType(Overlay),
            matching: find.byType(TextButton),
          ),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a read-only textarea takes no toolbar', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // No keyboard opens, so a Done button would dismiss nothing.
        await tester.pumpWidget(
          wrap(const MSTextarea(placeholder: 'Notes', readOnly: true)),
        );

        await tester.tap(find.byType(MSTextarea));
        await tester.pump(const Duration(milliseconds: 16));

        expect(
          find.descendant(
            of: find.byType(Overlay),
            matching: find.byType(TextButton),
          ),
          findsNothing,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('an external focus node is not disposed by the textarea', (
      tester,
    ) async {
      final _ProbeFocusNode external = _ProbeFocusNode();
      addTearDown(external.dispose);

      await tester.pumpWidget(wrap(MSTextarea(focusNode: external)));
      await tester.pumpWidget(wrap(const SizedBox.shrink()));

      // Disposing a node the caller owns would throw on their next use of it,
      // which is the failure this asserts against rather than a leak.
      expect(external.retainsAListener, isFalse);
      expect(() => external.requestFocus(), returnsNormally);
    });
  });
}

/// A [FocusNode] that can answer whether anything is still listening to it.
///
/// `ChangeNotifier.hasListeners` is `@protected`, so reading it from a test body
/// is an analyzer warning and `dart analyze` treats warnings as failures in CI.
/// A subclass is where that member is legitimately visible, which keeps the
/// assertion exactly as strong as it was: the widget must leave a caller-owned
/// node with no listener of its own attached after unmount.
class _ProbeFocusNode extends FocusNode {
  /// Whether any listener is still attached.
  bool get retainsAListener => hasListeners;
}
