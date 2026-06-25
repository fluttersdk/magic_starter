import 'package:flutter/material.dart' hide BottomSheet;
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
      colors: {'primary': Colors.indigo},
    );
    return WindTheme(
      data: themeData,
      child: MaterialApp(
        theme: themeData.toThemeData(),
        home: Scaffold(body: widget),
      ),
    );
  }

  group('BottomSheet', () {
    testWidgets('renders title when provided', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(
        const BottomSheet(
          title: 'Sheet Title',
          body: Text('sheet body'),
        ),
      ));

      expect(find.text('Sheet Title'), findsOneWidget);
    });

    testWidgets('renders body content', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(
        const BottomSheet(
          body: Text('unique sheet content'),
        ),
      ));

      expect(find.text('unique sheet content'), findsOneWidget);
    });

    testWidgets('static show() opens bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => BottomSheet.show(
              context,
              title: 'Bottom Sheet',
              body: const Text('sheet body'),
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Bottom Sheet'), findsOneWidget);
      expect(find.text('sheet body'), findsOneWidget);
    });

    testWidgets('renders footer via footerBuilder', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(
        BottomSheet(
          body: const Text('body'),
          footerBuilder: (_) => const Text('footer content'),
        ),
      ));

      expect(find.text('footer content'), findsOneWidget);
    });
  });

  // Verify BottomSheet is re-exported from index.dart
  test('BottomSheet is re-exported from index.dart', () {
    expect(BottomSheet, isNotNull);
  });
}
