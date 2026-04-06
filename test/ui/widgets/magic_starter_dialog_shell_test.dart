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

  testWidgets('renders title text when provided', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(
      const MagicStarterDialogShell(
        title: 'Test Title',
        body: Text('body content'),
      ),
    ));

    expect(find.text('Test Title'), findsOneWidget);
  });

  testWidgets('renders description text when provided', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(
      const MagicStarterDialogShell(
        title: 'Test Title',
        description: 'Test description text',
        body: Text('body content'),
      ),
    ));

    expect(find.text('Test description text'), findsOneWidget);
  });

  testWidgets('renders body content widget', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(
      const MagicStarterDialogShell(
        body: Text('unique body content'),
      ),
    ));

    expect(find.text('unique body content'), findsOneWidget);
  });

  testWidgets('renders footer widget when footerBuilder is provided',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(
      MagicStarterDialogShell(
        body: const Text('body content'),
        footerBuilder: (_) => const Text('footer content'),
      ),
    ));

    expect(find.text('footer content'), findsOneWidget);
  });

  testWidgets('footer section absent when footerBuilder is null',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(
      const MagicStarterDialogShell(
        body: Text('body content'),
      ),
    ));

    // The footer placeholder key must not be present when footerBuilder is null.
    expect(
      find.byKey(const Key('magic_starter_dialog_shell_footer')),
      findsNothing,
    );
  });

  testWidgets('footerBuilder callback receives a valid BuildContext',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    BuildContext? capturedContext;

    await tester.pumpWidget(wrap(
      MagicStarterDialogShell(
        body: const Text('body content'),
        footerBuilder: (dialogContext) {
          capturedContext = dialogContext;
          return const Text('footer with context');
        },
      ),
    ));

    expect(find.text('footer with context'), findsOneWidget);
    expect(capturedContext, isNotNull);
    // Verify the context is a valid mounted context by reading media query.
    expect(MediaQuery.maybeOf(capturedContext!), isNotNull);
  });

  testWidgets('body uses ListView so it shrinks to content height',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(
      MagicStarterDialogShell(
        body: const Text('short body'),
        footerBuilder: (_) => const Text('footer below body'),
      ),
    ));

    // Both widgets must be rendered.
    expect(find.text('short body'), findsOneWidget);
    expect(find.text('footer below body'), findsOneWidget);

    // Geometry assertion: footer must sit directly below the body content
    // without an expanding gap. The distance between body bottom and footer
    // top should be small (only theme padding, not leftover Flexible space).
    final bodyBottom = tester.getBottomLeft(find.text('short body')).dy;
    final footerTop = tester.getTopLeft(find.text('footer below body')).dy;
    final gap = footerTop - bodyBottom;

    // Gap should be modest (theme padding) — not hundreds of pixels.
    expect(gap, lessThan(80));

    // Confirm no SingleChildScrollView is a descendant of the dialog shell
    // (the body is now wrapped by ListView, not SingleChildScrollView).
    final shellFinder = find.byType(MagicStarterDialogShell);
    expect(
      find.descendant(
        of: shellFinder,
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });

  group('mobile overflow safety', () {
    testWidgets('Dialog has vertical insetPadding', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(
        const MagicStarterDialogShell(
          title: 'Test',
          body: Text('body'),
        ),
      ));

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final insetPadding = dialog.insetPadding as EdgeInsets;

      expect(insetPadding.top, greaterThan(0));
      expect(insetPadding.bottom, greaterThan(0));
      expect(insetPadding.left, equals(16));
      expect(insetPadding.right, equals(16));
    });

    testWidgets('maxHeight accounts for viewPadding safe area', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = const FakeViewPadding(
        top: 44,
        bottom: 34,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);

      await tester.pumpWidget(wrap(
        const MagicStarterDialogShell(
          title: 'Test',
          body: Text('body'),
        ),
      ));

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox &&
              widget.constraints.maxHeight != double.infinity &&
              widget.constraints.maxWidth != double.infinity,
        ),
      );
      final maxHeight = constrainedBox.constraints.maxHeight;

      // Screen height = 800, viewPadding top = 44, bottom = 34
      // Safe height = 800 - 44 - 34 = 722
      // maxHeight should be 722 * 0.85 = 613.7
      // Without safe area it would be 800 * 0.85 = 680
      expect(maxHeight, lessThan(680));
      expect(maxHeight, closeTo(613.7, 1.0));
    });

    testWidgets('body scrolls without overflow when content exceeds viewport',
        (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(
        MagicStarterDialogShell(
          title: 'Overflow Test',
          body: Column(
            children: List.generate(
              20,
              (i) => SizedBox(height: 60, child: Text('Item $i')),
            ),
          ),
          footerBuilder: (_) => const Text('sticky footer'),
        ),
      ));

      // No overflow error should occur.
      expect(tester.takeException(), isNull);

      // Footer must still be rendered (sticky).
      expect(
        find.byKey(const Key('magic_starter_dialog_shell_footer')),
        findsOneWidget,
      );

      // ListView must be present for scrolling.
      final shellFinder = find.byType(MagicStarterDialogShell);
      expect(
        find.descendant(
          of: shellFinder,
          matching: find.byType(ListView),
        ),
        findsOneWidget,
      );
    });

    testWidgets('safeHeight is smaller than raw screen height', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = const FakeViewPadding(
        top: 44,
        bottom: 34,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);

      await tester.pumpWidget(wrap(
        const MagicStarterDialogShell(
          title: 'Test',
          body: Text('body'),
        ),
      ));

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox &&
              widget.constraints.maxHeight != double.infinity &&
              widget.constraints.maxWidth != double.infinity,
        ),
      );
      final maxHeight = constrainedBox.constraints.maxHeight;

      // Screen height = 600, viewPadding top = 44, bottom = 34
      // Safe height = 600 - 44 - 34 = 522
      // maxHeight should be 522 * 0.85 = 443.7
      // Without safe area it would be 600 * 0.85 = 510
      expect(maxHeight, lessThan(510));
      expect(maxHeight, closeTo(443.7, 1.0));
    });
  });

  testWidgets(
    'reads containerClassName from MagicStarter.manager.modalTheme',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      MagicStarter.manager.modalTheme = const MagicStarterModalTheme(
        containerClassName: 'rounded-3xl bg-red-50',
      );

      await tester.pumpWidget(wrap(
        const MagicStarterDialogShell(
          body: Text('body content'),
        ),
      ));

      // Widget must render without error when a custom containerClassName is set.
      expect(find.byType(MagicStarterDialogShell), findsOneWidget);
    },
  );

  testWidgets(
    'reads titleClassName from MagicStarter.manager.modalTheme',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      MagicStarter.manager.modalTheme = const MagicStarterModalTheme(
        titleClassName: 'text-2xl font-black text-red-600',
      );

      await tester.pumpWidget(wrap(
        const MagicStarterDialogShell(
          title: 'Styled Title',
          body: Text('body content'),
        ),
      ));

      // Widget must render the title without error when a custom titleClassName is set.
      expect(find.text('Styled Title'), findsOneWidget);
    },
  );
}
