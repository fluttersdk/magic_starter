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

    testWidgets('scrolls its body by default', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(const MSBottomSheet(body: SizedBox(key: Key('b'), height: 10))),
      );

      expect(
        find.ancestor(
          of: find.byKey(const Key('b')),
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a non-scrollable sheet hands its body the bounded height', (
      tester,
    ) async {
      // A body with its own list (a paged table under a fixed chart) used to
      // nest that list inside the sheet's scroll view: two scrollbars, and
      // the list had to guess a fixed height.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      BoxConstraints? seen;
      await tester.pumpWidget(
        wrap(
          MSBottomSheet(
            scrollable: false,
            body: LayoutBuilder(
              builder: (context, constraints) {
                seen = constraints;

                return const SizedBox(key: Key('b'), height: 10);
              },
            ),
          ),
        ),
      );

      expect(
        find.ancestor(
          of: find.byKey(const Key('b')),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(seen!.hasBoundedHeight, isTrue);
      expect(seen!.maxHeight, lessThanOrEqualTo(800 * 0.85));
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

    testWidgets('keeps the strip the keyboard has not covered yet', (
      tester,
    ) async {
      // A dismissing keyboard descends through intermediate values, so there
      // are frames where the inset is smaller than the home indicator. A branch
      // on `keyboardInset > 0` drops the strip to zero across all of them and
      // the sheet's last control sits on the indicator with nothing under it.
      // 20 of inset against a 34 indicator leaves 14.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 20);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        wrap(
          MSBottomSheet(
            body: const Text('body'),
            footerBuilder: (_) => const Text('footer content'),
          ),
        ),
      );

      final double panelBottom = tester
          .getRect(find.byKey(const Key('bottom_sheet_footer')))
          .bottom;
      final double sheetBottom = tester
          .getRect(find.byType(MSBottomSheet))
          .bottom;

      expect(sheetBottom - panelBottom, 14.0);
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

  group('dialogBreakpoint', () {
    void setWidth(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Widget opener({
      String? dialogBreakpoint,
      bool scrollable = true,
      Widget body = const Text('sheet body'),
      ValueChanged<Object?>? onResult,
    }) {
      return wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final Object? result = await MSBottomSheet.show<String>(
                context,
                title: 'Move',
                description: 'Pick a place',
                body: body,
                scrollable: scrollable,
                dialogBreakpoint: dialogBreakpoint,
                footerBuilder: (sheetContext) => ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop('moved'),
                  child: const Text('Done'),
                ),
              );
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        ),
      );
    }

    testWidgets('presents a dialog from the breakpoint up', (tester) async {
      setWidth(tester, 1280);

      await tester.pumpWidget(opener(dialogBreakpoint: 'lg'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(MSDialog), findsOneWidget);
      expect(find.byType(MSBottomSheet), findsNothing);
      expect(find.text('Move'), findsOneWidget);
      expect(find.text('Pick a place'), findsOneWidget);
      expect(find.text('sheet body'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('stays a sheet below the breakpoint', (tester) async {
      setWidth(tester, 390);

      await tester.pumpWidget(opener(dialogBreakpoint: 'lg'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(MSBottomSheet), findsOneWidget);
      expect(find.byType(MSDialog), findsNothing);
    });

    testWidgets('without the argument a wide screen still gets a sheet', (
      tester,
    ) async {
      setWidth(tester, 1440);

      await tester.pumpWidget(opener());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(MSBottomSheet), findsOneWidget);
      expect(find.byType(MSDialog), findsNothing);
    });

    testWidgets('the footer pops the dialog with its result', (tester) async {
      setWidth(tester, 1280);
      Object? result;

      await tester.pumpWidget(
        opener(dialogBreakpoint: 'lg', onResult: (value) => result = value),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(MSDialog), findsNothing);
      expect(result, 'moved');
    });

    testWidgets('a non-scrollable body keeps its bounded height in a dialog', (
      tester,
    ) async {
      setWidth(tester, 1280);
      BoxConstraints? seen;

      await tester.pumpWidget(
        opener(
          dialogBreakpoint: 'lg',
          scrollable: false,
          body: LayoutBuilder(
            builder: (context, constraints) {
              seen = constraints;

              return const SizedBox(key: Key('b'), height: 10);
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(MSDialog), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('b')),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(seen!.hasBoundedHeight, isTrue);
    });

    testWidgets('an unknown breakpoint fails loudly', (tester) async {
      setWidth(tester, 1280);
      Object? error;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                try {
                  MSBottomSheet.show<void>(
                    context,
                    body: const Text('x'),
                    dialogBreakpoint: 'desktop',
                  );
                } on StateError catch (e) {
                  error = e;
                }
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(error, isA<StateError>());
      expect(
        (error! as StateError).message,
        contains('MSBottomSheet.show(dialogBreakpoint:)'),
      );
    });
  });

  // Verify BottomSheet is re-exported from index.dart
  test('BottomSheet is re-exported from index.dart', () {
    expect(MSBottomSheet, isNotNull);
  });
}
