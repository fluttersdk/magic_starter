import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/confirm_dialog/index.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Magic.singleton('log', () => LogManager());
    Config.set('logging', {
      'default': 'console',
      'channels': {
        'console': {'driver': 'console', 'level': 'debug'},
      },
    });
    Config.set('wind.colors.primary', 'indigo');
  });

  Widget wrap(Widget widget) {
    final themeData = WindThemeData(
      colors: {
        'primary': Colors.indigo,
        'danger': Colors.red,
        'warning': Colors.amber,
      },
    );
    return WindTheme(
      data: themeData,
      child: MaterialApp(
        theme: themeData.toThemeData(),
        home: Scaffold(body: SizedBox(width: 1200, height: 800, child: widget)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recipe variant-class assertions (TDD red)
  // ---------------------------------------------------------------------------

  group('confirm dialog recipe', () {
    test('primary variant emits primaryButtonClassName', () {
      final theme = const MagicStarterModalTheme();
      final cls = resolveConfirmButtonClassName(
        ConfirmDialogVariant.primary,
        theme,
      );
      expect(cls, equals(theme.primaryButtonClassName));
    });

    test('danger variant emits dangerButtonClassName', () {
      final theme = const MagicStarterModalTheme();
      final cls = resolveConfirmButtonClassName(
        ConfirmDialogVariant.danger,
        theme,
      );
      expect(cls, equals(theme.dangerButtonClassName));
    });

    test('warning variant emits warningButtonClassName', () {
      final theme = const MagicStarterModalTheme();
      final cls = resolveConfirmButtonClassName(
        ConfirmDialogVariant.warning,
        theme,
      );
      expect(cls, equals(theme.warningButtonClassName));
    });
  });

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  group('ConfirmDialog rendering', () {
    testWidgets('renders title text', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(const MSConfirmDialog(title: 'Are you sure?')),
      );

      expect(find.text('Are you sure?'), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          const MSConfirmDialog(
            title: 'Delete?',
            description: 'This cannot be undone.',
          ),
        ),
      );

      expect(find.text('This cannot be undone.'), findsOneWidget);
    });

    testWidgets('renders confirm and cancel buttons with default labels', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MSConfirmDialog(title: 'Confirm?')));

      expect(find.text('common.confirm'), findsOneWidget);
      expect(find.text('common.cancel'), findsOneWidget);
    });

    testWidgets('default variant is primary', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MSConfirmDialog(title: 'Confirm?')));

      final dialog = tester.widget<MSConfirmDialog>(
        find.byType(MSConfirmDialog),
      );
      expect(dialog.variant, ConfirmDialogVariant.primary);
    });

    testWidgets('danger variant is set', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          const MSConfirmDialog(
            title: 'Delete?',
            variant: ConfirmDialogVariant.danger,
          ),
        ),
      );

      final dialog = tester.widget<MSConfirmDialog>(
        find.byType(MSConfirmDialog),
      );
      expect(dialog.variant, ConfirmDialogVariant.danger);
    });
  });

  // ---------------------------------------------------------------------------
  // Return values
  // ---------------------------------------------------------------------------

  group('ConfirmDialog return values', () {
    testWidgets('returns false on cancel', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool result = true;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await MSConfirmDialog.show(context, title: 'Delete?');
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('common.cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('returns true on confirm', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool result = false;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await MSConfirmDialog.show(
                  context,
                  title: 'Delete?',
                  onConfirm: () async {},
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Button layout
  // ---------------------------------------------------------------------------

  testWidgets('footer buttons are compact and right-aligned', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const MSConfirmDialog(title: 'Confirm?')));

    final footerWrapFinder = find
        .ancestor(of: find.text('common.cancel'), matching: find.byType(Wrap))
        .first;

    final wrapWidget = tester.widget<Wrap>(footerWrapFinder);
    expect(wrapWidget.alignment, WrapAlignment.end);
  });

  // ---------------------------------------------------------------------------
  // ConfirmDialogVariant enum stability (import-path contract)
  // ---------------------------------------------------------------------------

  test('ConfirmDialogVariant has primary, danger, warning values', () {
    expect(ConfirmDialogVariant.values.length, 3);
    expect(ConfirmDialogVariant.primary, isNotNull);
    expect(ConfirmDialogVariant.danger, isNotNull);
    expect(ConfirmDialogVariant.warning, isNotNull);
  });
}
