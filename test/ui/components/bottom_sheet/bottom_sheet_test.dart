import 'package:flutter/material.dart' hide BottomSheet;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/bottom_sheet/bottom_sheet_panel.dart';

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

  // A sheet holding unsaved input stays open on a drag, a scrim tap and Back
  // while its guard refuses, and tells the caller so it can ask the person.
  group('canDismiss', () {
    late int blocked;
    late Object? result;

    setUp(() {
      blocked = 0;
      result = #unset;
    });

    void setWidth(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// Opens a sheet whose text field turns [canDismiss] false on its first
    /// keystroke, the way a form reports itself dirty.
    Future<void> open(
      WidgetTester tester, {
      ValueNotifier<bool>? canDismiss,
      String? dialogBreakpoint,
    }) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await MSBottomSheet.show<String>(
                  context,
                  title: 'Edit',
                  body: TextField(onChanged: (_) => canDismiss?.value = false),
                  dialogBreakpoint: dialogBreakpoint,
                  canDismiss: canDismiss,
                  onDismissBlocked: () => blocked++,
                  footerBuilder: (sheetContext) => ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop('saved'),
                    child: const Text('Save'),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    Future<void> scrimTap(WidgetTester tester) async {
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
    }

    Future<void> back(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    // On the drag handle: the body is a scroll view that may take a vertical
    // drag for itself.
    Future<void> dragDown(WidgetTester tester) async {
      final Rect panel = tester.getRect(find.byType(MSBottomSheetPanel));
      await tester.flingFrom(
        Offset(panel.center.dx, panel.top + 8),
        const Offset(0, 600),
        3000,
      );
      await tester.pumpAndSettle();
    }

    final Map<String, Future<void> Function(WidgetTester)> gestures = {
      'a scrim tap': scrimTap,
      'Back': back,
      'a drag down': dragDown,
    };

    for (final gesture in gestures.entries) {
      testWidgets('without a guard ${gesture.key} closes it', (tester) async {
        setWidth(tester, 390);

        await open(tester);
        await gesture.value(tester);

        expect(result, isNull);
        expect(find.byType(MSBottomSheet), findsNothing);
        expect(blocked, 0);
      });

      testWidgets('an allowing guard lets ${gesture.key} close it', (
        tester,
      ) async {
        setWidth(tester, 390);

        await open(tester, canDismiss: ValueNotifier<bool>(true));
        await gesture.value(tester);

        expect(result, isNull);
        expect(find.byType(MSBottomSheet), findsNothing);
        expect(blocked, 0);
      });

      testWidgets('a refusing guard keeps it open on ${gesture.key}', (
        tester,
      ) async {
        setWidth(tester, 390);

        await open(tester, canDismiss: ValueNotifier<bool>(false));
        await gesture.value(tester);

        expect(result, #unset);
        expect(find.byType(MSBottomSheet), findsOneWidget);
        // A drag is switched off rather than refused, so only a scrim tap
        // and Back reach the caller.
        expect(blocked, gesture.key == 'a drag down' ? 0 : 1);
      });

      testWidgets('a guard that refuses after opening holds on '
          '${gesture.key}, and lets go once it allows again', (tester) async {
        setWidth(tester, 390);
        final canDismiss = ValueNotifier<bool>(true);

        await open(tester, canDismiss: canDismiss);
        await tester.enterText(find.byType(TextField), 'dirty');
        await tester.pump();
        expect(canDismiss.value, isFalse);

        await gesture.value(tester);
        expect(find.byType(MSBottomSheet), findsOneWidget);
        expect(blocked, gesture.key == 'a drag down' ? 0 : 1);
        expect(find.text('dirty'), findsOneWidget);

        canDismiss.value = true;
        await tester.pump();
        await gesture.value(tester);

        expect(result, isNull);
        expect(find.byType(MSBottomSheet), findsNothing);
      });
    }

    testWidgets('a refusing guard still lets the footer close the sheet', (
      tester,
    ) async {
      setWidth(tester, 390);

      await open(tester, canDismiss: ValueNotifier<bool>(false));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, 'saved');
      expect(blocked, 0);
    });

    group('as a dialog', () {
      final Map<String, Future<void> Function(WidgetTester)> dismissals = {
        'a barrier tap': scrimTap,
        'Back': back,
      };

      for (final dismissal in dismissals.entries) {
        testWidgets('a refusing guard keeps it open on ${dismissal.key} and '
            'reports it', (tester) async {
          setWidth(tester, 1440);
          final canDismiss = ValueNotifier<bool>(false);

          await open(tester, canDismiss: canDismiss, dialogBreakpoint: 'lg');
          expect(find.byType(Dialog), findsOneWidget);

          await dismissal.value(tester);
          expect(result, #unset);
          expect(find.byType(MSDialog), findsOneWidget);
          expect(blocked, 1);

          canDismiss.value = true;
          await tester.pump();
          await dismissal.value(tester);

          expect(result, isNull);
          expect(find.byType(MSDialog), findsNothing);
          expect(blocked, 1);
        });
      }

      testWidgets('a guard that refuses after opening holds the barrier', (
        tester,
      ) async {
        setWidth(tester, 1440);
        final canDismiss = ValueNotifier<bool>(true);

        await open(tester, canDismiss: canDismiss, dialogBreakpoint: 'lg');
        await tester.enterText(find.byType(TextField), 'dirty');
        await tester.pump();
        await scrimTap(tester);

        expect(find.byType(MSDialog), findsOneWidget);
        expect(blocked, 1);
      });
    });

    testWidgets('the sheet presentation honours the guard at every width', (
      tester,
    ) async {
      setWidth(tester, 1440);
      MagicStarter.useModalTheme(
        MagicStarter.manager.modalTheme.copyWith(
          presentation: MagicStarterModalPresentation.sheet,
        ),
      );

      await open(
        tester,
        canDismiss: ValueNotifier<bool>(false),
        dialogBreakpoint: 'lg',
      );
      expect(find.byType(MSDialog), findsNothing);

      await dragDown(tester);
      await scrimTap(tester);
      await back(tester);

      expect(find.byType(MSBottomSheet), findsOneWidget);
      expect(blocked, 2);
    });
  });

  // Verify BottomSheet is re-exported from index.dart
  test('BottomSheet is re-exported from index.dart', () {
    expect(MSBottomSheet, isNotNull);
  });
}
