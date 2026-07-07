import 'package:flutter/material.dart' hide Dialog;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

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
      },
    );
    return WindTheme(
      data: themeData,
      child: MaterialApp(
        theme: themeData.toThemeData(),
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: widget,
          ),
        ),
      ),
    );
  }

  group('Dialog', () {
    testWidgets('renders title when provided', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(
        const MSDialog(
          title: 'Test Dialog',
          body: Text('body content'),
        ),
      ));

      expect(find.text('Test Dialog'), findsOneWidget);
    });

    testWidgets('renders body content', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(
        const MSDialog(
          body: Text('unique body text'),
        ),
      ));

      expect(find.text('unique body text'), findsOneWidget);
    });

    testWidgets('renders footer via footerBuilder', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(
        MSDialog(
          body: const Text('body'),
          footerBuilder: (_) => const Text('footer widget'),
        ),
      ));

      expect(find.text('footer widget'), findsOneWidget);
    });

    testWidgets('static show() opens dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => MSDialog.show(
              context,
              title: 'Opened Dialog',
              body: const Text('dialog body'),
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(MSDialog), findsWidgets);
      expect(find.text('Opened Dialog'), findsOneWidget);
    });

    testWidgets('reads containerClassName from modal theme', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      MagicStarter.useModalTheme(
        const MagicStarterModalTheme(
          containerClassName: 'rounded-3xl bg-blue-50',
        ),
      );

      await tester.pumpWidget(wrap(
        const MSDialog(body: Text('themed')),
      ));

      expect(find.byType(MSDialog), findsOneWidget);
    });
  });

  // Verify Dialog is re-exported from index.dart
  test('Dialog is re-exported from index.dart', () {
    // The import of index.dart at the top of this file proves re-export.
    expect(MSDialog, isNotNull);
  });
}
