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
    final themeData = WindThemeData(colors: {'primary': Colors.indigo});
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

      await tester.pumpWidget(
        wrap(
          const MSBottomSheet(title: 'Sheet Title', body: Text('sheet body')),
        ),
      );

      expect(find.text('Sheet Title'), findsOneWidget);
    });

    testWidgets('renders body content', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(const MSBottomSheet(body: Text('unique sheet content'))),
      );

      expect(find.text('unique sheet content'), findsOneWidget);
    });

    testWidgets('static show() opens bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => MSBottomSheet.show(
                context,
                title: 'Bottom Sheet',
                body: const Text('sheet body'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

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

      await tester.pumpWidget(
        wrap(
          MSBottomSheet(
            body: const Text('body'),
            footerBuilder: (_) => const Text('footer content'),
          ),
        ),
      );

      expect(find.text('footer content'), findsOneWidget);
    });

    testWidgets('lifts clear of the software keyboard', (tester) async {
      // Through `show()` rather than inline, because the defect only exists
      // once the sheet is bottom-anchored: rendered inline the panel starts at
      // the top of the body and its footer clears the keys whatever the
      // padding is. A first attempt at this test asserted against the inline
      // form, and a mutant that removed the padding entirely passed it.
      //
      // 800 tall, 300 of it keyboard. `showModalBottomSheet` compensates for
      // none of that on its own: `viewInsets` appears nowhere in Flutter's
      // material/bottom_sheet.dart.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => MSBottomSheet.show(
                context,
                body: const Text('sheet body'),
                footerBuilder: (_) => const Text('footer content'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The footer is the sheet's lowest control, so it is the one a keyboard
      // covers first. It has to end above the keyboard's top edge at 500.
      final double footerBottom = tester
          .getRect(find.text('footer content'))
          .bottom;

      expect(footerBottom, lessThanOrEqualTo(500.0));
    });

    testWidgets('states that it has spent the keyboard inset', (tester) async {
      // A body widget reading `viewInsets.bottom` for itself would otherwise
      // reserve the same 300 pixels a second time, inside a panel that has
      // already moved clear of them.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      late double insetSeenByBody;

      await tester.pumpWidget(
        wrap(
          MSBottomSheet(
            body: Builder(
              builder: (context) {
                insetSeenByBody = MediaQuery.viewInsetsOf(context).bottom;
                return const Text('body');
              },
            ),
          ),
        ),
      );

      expect(insetSeenByBody, 0.0);
    });
  });

  // Verify BottomSheet is re-exported from index.dart
  test('BottomSheet is re-exported from index.dart', () {
    expect(MSBottomSheet, isNotNull);
  });
}
