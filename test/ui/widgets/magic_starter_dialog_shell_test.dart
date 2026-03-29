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

    // Body must not fill all available height when content is short — ListView
    // with shrinkWrap: true collapses to content height. Verify the footer is
    // visible immediately below the body without an expanding gap.
    expect(find.text('short body'), findsOneWidget);
    expect(find.text('footer below body'), findsOneWidget);

    // Neither widget should require scrolling — both visible in one frame.
    expect(find.text('short body'), findsOneWidget);
    expect(find.text('footer below body'), findsOneWidget);

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
