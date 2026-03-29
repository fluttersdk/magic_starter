import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  setUp(() async {
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
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1200,
              height: 800,
              child: widget,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  testWidgets('renders title text', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(
      wrap(
        const MagicStarterConfirmDialog(
          title: 'Delete item',
        ),
      ),
    );

    expect(find.text('Delete item'), findsOneWidget);
  });

  testWidgets('renders description text', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(
      wrap(
        const MagicStarterConfirmDialog(
          title: 'Delete item',
          description: 'This action cannot be undone.',
        ),
      ),
    );

    expect(find.text('This action cannot be undone.'), findsOneWidget);
  });

  testWidgets(
    'renders confirm and cancel buttons with default labels',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        wrap(
          const MagicStarterConfirmDialog(title: 'Confirm?'),
        ),
      );

      expect(find.text('common.confirm'), findsOneWidget);
      expect(find.text('common.cancel'), findsOneWidget);
    },
  );

  testWidgets(
    'renders custom confirm and cancel labels when provided',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        wrap(
          const MagicStarterConfirmDialog(
            title: 'Remove?',
            confirmLabel: 'Yes, remove',
            cancelLabel: 'No, keep it',
          ),
        ),
      );

      expect(find.text('Yes, remove'), findsOneWidget);
      expect(find.text('No, keep it'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Return values
  // ---------------------------------------------------------------------------

  testWidgets(
    'returns false when cancel button is tapped',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      bool result = true;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await MagicStarterConfirmDialog.show(
                  context,
                  title: 'Are you sure?',
                );
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
    },
  );

  testWidgets(
    'returns true when confirm button is tapped and onConfirm succeeds',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      bool result = false;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await MagicStarterConfirmDialog.show(
                  context,
                  title: 'Are you sure?',
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
    },
  );

  // ---------------------------------------------------------------------------
  // Variants
  // ---------------------------------------------------------------------------

  testWidgets(
    'default variant is primary',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        wrap(
          const MagicStarterConfirmDialog(title: 'Confirm?'),
        ),
      );

      final dialog = tester.widget<MagicStarterConfirmDialog>(
        find.byType(MagicStarterConfirmDialog),
      );

      expect(dialog.variant, ConfirmDialogVariant.primary);
    },
  );

  testWidgets(
    'ConfirmDialogVariant.danger renders danger-styled confirm button',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        wrap(
          const MagicStarterConfirmDialog(
            title: 'Delete?',
            variant: ConfirmDialogVariant.danger,
          ),
        ),
      );

      // The confirm button should exist and the dialog carries danger variant.
      final dialog = tester.widget<MagicStarterConfirmDialog>(
        find.byType(MagicStarterConfirmDialog),
      );

      expect(dialog.variant, ConfirmDialogVariant.danger);
      expect(find.text('common.confirm'), findsOneWidget);
    },
  );

  testWidgets(
    'ConfirmDialogVariant.warning renders warning-styled confirm button',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        wrap(
          const MagicStarterConfirmDialog(
            title: 'Archive?',
            variant: ConfirmDialogVariant.warning,
          ),
        ),
      );

      final dialog = tester.widget<MagicStarterConfirmDialog>(
        find.byType(MagicStarterConfirmDialog),
      );

      expect(dialog.variant, ConfirmDialogVariant.warning);
      expect(find.text('common.confirm'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Static show() factory
  // ---------------------------------------------------------------------------

  testWidgets(
    'static show() opens dialog via Builder pattern',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await MagicStarterConfirmDialog.show(
                  context,
                  title: 'Are you sure?',
                  description: 'This cannot be undone.',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.byType(MagicStarterConfirmDialog),
        findsOneWidget,
      );
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Button layout
  // ---------------------------------------------------------------------------

  testWidgets(
    'footer buttons are compact and right-aligned — no flex-1 wrappers',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        wrap(
          const MagicStarterConfirmDialog(title: 'Confirm?'),
        ),
      );

      // Locate the specific footer Wrap that contains the cancel button.
      final footerWrapFinder = find
          .ancestor(
            of: find.text('common.cancel'),
            matching: find.byType(Wrap),
          )
          .first;

      final wrapWidget = tester.widget<Wrap>(footerWrapFinder);

      // Wrap alignment must be end (right-aligned).
      expect(wrapWidget.alignment, WrapAlignment.end);

      // Within the footer container, there must be no flex-1 WDiv wrappers.
      final flex1WrapperFinder = find.descendant(
        of: footerWrapFinder,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is WDiv && (widget.className?.contains('flex-1') ?? false),
        ),
      );
      expect(flex1WrapperFinder, findsNothing);

      // And no WButton in the footer should be forced to full width.
      final fullWidthButtonFinder = find.descendant(
        of: footerWrapFinder,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is WButton &&
              (widget.className?.contains('w-full') ?? false),
        ),
      );
      expect(fullWidthButtonFinder, findsNothing);
    },
  );

  // ---------------------------------------------------------------------------
  // Theme integration
  // ---------------------------------------------------------------------------

  testWidgets(
    'custom MagicStarterModalTheme className appears in dialog',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      MagicStarter.useModalTheme(
        const MagicStarterModalTheme(
          containerClassName: 'rounded-3xl bg-white',
        ),
      );

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await MagicStarterConfirmDialog.show(
                  context,
                  title: 'Themed dialog',
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // The dialog should open and carry the theme override.
      expect(find.byType(MagicStarterConfirmDialog), findsOneWidget);

      final dialog = tester.widget<MagicStarterConfirmDialog>(
        find.byType(MagicStarterConfirmDialog),
      );

      expect(
        MagicStarter.modalTheme.containerClassName,
        'rounded-3xl bg-white',
      );
      expect(dialog, isNotNull);
    },
  );
}
