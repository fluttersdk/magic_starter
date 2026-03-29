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

  testWidgets('MagicStarterPasswordConfirmDialog renders correctly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(wrap(const MagicStarterPasswordConfirmDialog()));
    expect(find.text('profile.confirm_password'), findsOneWidget);
    expect(find.text('profile.confirm_password_description'), findsOneWidget);
    expect(find.text('common.confirm'), findsOneWidget);
    expect(find.text('common.cancel'), findsOneWidget);
    expect(find.byType(WFormInput), findsOneWidget);
    expect(find.byType(WButton), findsOneWidget);
  });

  testWidgets('MagicStarterPasswordConfirmDialog returns false on cancel',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    bool result = true;

    await tester.pumpWidget(wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await MagicStarterPasswordConfirmDialog.show(context);
          },
          child: const Text('Show'),
        ),
      ),
    ));

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('common.cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('displays error from onConfirm callback', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            await MagicStarterPasswordConfirmDialog.show(
              context,
              onConfirm: (password) async => 'Invalid password',
            );
          },
          child: const Text('Show'),
        ),
      ),
    ));

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    // Enter password and tap confirm
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'wrongpass');
    await tester.tap(find.text('common.confirm'));
    await tester.pumpAndSettle();

    // Error message should appear inline
    expect(find.text('Invalid password'), findsOneWidget);
    // Dialog should still be open
    expect(find.byType(MagicStarterPasswordConfirmDialog), findsOneWidget);
  });

  testWidgets('MagicStarterPasswordConfirmDialog returns true on confirm',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    bool result = false;

    await tester.pumpWidget(wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await MagicStarterPasswordConfirmDialog.show(
              context,
              onConfirm: (password) async => null, // success
            );
          },
          child: const Text('Show'),
        ),
      ),
    ));

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    // Find the text field inside WFormInput and enter text
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'secretpassword');
    await tester.pump();

    await tester.tap(find.text('common.confirm'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  group('compact right-aligned button layout', () {
    testWidgets('footer has no flex-1 wrapper divs', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MagicStarterPasswordConfirmDialog()));

      // Locate the footer container (the Wrap rendered by Wind's justify-end).
      final footerWrapFinder = find
          .ancestor(
            of: find.text('common.cancel'),
            matching: find.byType(Wrap),
          )
          .first;

      // No flex-1 WDiv wrappers inside the footer.
      final flex1Divs = find.descendant(
        of: footerWrapFinder,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is WDiv && (widget.className?.contains('flex-1') ?? false),
        ),
      );
      expect(flex1Divs, findsNothing);
    });

    testWidgets('footer container uses justify-end for right-alignment',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MagicStarterPasswordConfirmDialog()));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is WDiv &&
              widget.className != null &&
              widget.className!.contains('justify-end'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('confirm WButton has no w-full className', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const MagicStarterPasswordConfirmDialog()));

      final wButtons = find.byWidgetPredicate(
        (widget) =>
            widget is WButton &&
            widget.className != null &&
            widget.className!.contains('w-full'),
      );
      expect(wButtons, findsNothing);
    });
  });

  group('modal theme integration', () {
    testWidgets('uses custom containerClassName from modal theme',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      MagicStarter.useModalTheme(
        const MagicStarterModalTheme(
          containerClassName: 'bg-custom-test-container rounded-3xl',
        ),
      );

      await tester.pumpWidget(wrap(const MagicStarterPasswordConfirmDialog()));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is WDiv &&
              widget.className != null &&
              widget.className!.contains('bg-custom-test-container'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses custom titleClassName from modal theme',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      MagicStarter.useModalTheme(
        const MagicStarterModalTheme(
          titleClassName: 'text-custom-title-class font-black',
        ),
      );

      await tester.pumpWidget(wrap(const MagicStarterPasswordConfirmDialog()));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is WText &&
              widget.className != null &&
              widget.className!.contains('text-custom-title-class'),
        ),
        findsOneWidget,
      );
    });
  });
}
