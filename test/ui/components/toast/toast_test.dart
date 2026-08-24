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

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: widget),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recipe variant-class assertions (TDD red)
  // ---------------------------------------------------------------------------

  group('toast recipe', () {
    test('default variant emits bg-surface token', () {
      final cls = buildToastRecipe()(
        variants: {kToastVariantAxis: ToastVariant.info.name},
      );
      expect(cls, contains('bg-surface'));
    });

    test('success variant emits bg-success token', () {
      final cls = buildToastRecipe()(
        variants: {kToastVariantAxis: ToastVariant.success.name},
      );
      expect(cls, contains('bg-success'));
    });

    test('error variant emits bg-destructive token', () {
      final cls = buildToastRecipe()(
        variants: {kToastVariantAxis: ToastVariant.error.name},
      );
      expect(cls, contains('bg-destructive'));
    });

    test('warning variant emits bg-warning token', () {
      final cls = buildToastRecipe()(
        variants: {kToastVariantAxis: ToastVariant.warning.name},
      );
      expect(cls, contains('bg-warning'));
    });
  });

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  group('Toast widget', () {
    testWidgets('renders message text', (tester) async {
      await tester.pumpWidget(
        wrap(const MSToast(message: 'Operation succeeded')),
      );

      expect(find.text('Operation succeeded'), findsOneWidget);
    });

    testWidgets('default variant is info', (tester) async {
      await tester.pumpWidget(wrap(const MSToast(message: 'Hello')));

      final toast = tester.widget<MSToast>(find.byType(MSToast));
      expect(toast.variant, ToastVariant.info);
    });

    testWidgets('success variant is set', (tester) async {
      await tester.pumpWidget(
        wrap(const MSToast(message: 'Done', variant: ToastVariant.success)),
      );

      final toast = tester.widget<MSToast>(find.byType(MSToast));
      expect(toast.variant, ToastVariant.success);
    });
  });

  // ---------------------------------------------------------------------------
  // ToastVariant enum stability
  // ---------------------------------------------------------------------------

  test('ToastVariant has info, success, warning, error values', () {
    expect(ToastVariant.values.length, 4);
    expect(ToastVariant.info, isNotNull);
    expect(ToastVariant.success, isNotNull);
    expect(ToastVariant.warning, isNotNull);
    expect(ToastVariant.error, isNotNull);
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Toast appends caller className onto the recipe base', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MSToast(message: 'hi', className: 'mt-10')),
    );
    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('rounded-lg'));
    expect(wDiv.className, contains('mt-10'));
  });
}
