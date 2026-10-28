import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/toast/toast.preview.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: widget),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recipe variant-class assertions (TDD red)
  // ---------------------------------------------------------------------------

  group('toast recipe', () {
    test('default variant emits bg-surface token', () {
      final cls = buildToastRecipe()(
        variants: {kToastVariantAxis: ToastVariant.info.name},
      );
      expect(cls, contains('bg-surface'));
    });

    test('success variant emits bg-success token', () {
      final cls = buildToastRecipe()(
        variants: {kToastVariantAxis: ToastVariant.success.name},
      );
      expect(cls, contains('bg-success'));
    });

    test('error variant emits bg-destructive token', () {
      final cls = buildToastRecipe()(
        variants: {kToastVariantAxis: ToastVariant.error.name},
      );
      expect(cls, contains('bg-destructive'));
    });

    test('warning variant emits bg-warning token', () {
      final cls = buildToastRecipe()(
        variants: {kToastVariantAxis: ToastVariant.warning.name},
      );
      expect(cls, contains('bg-warning'));
    });
  });

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  group('Toast widget', () {
    testWidgets('renders message text', (tester) async {
      await tester.pumpWidget(
        wrap(const MSToast(message: 'Operation succeeded')),
      );

      expect(find.text('Operation succeeded'), findsOneWidget);
    });

    testWidgets('default variant is info', (tester) async {
      await tester.pumpWidget(wrap(const MSToast(message: 'Hello')));

      final toast = tester.widget<MSToast>(find.byType(MSToast));
      expect(toast.variant, ToastVariant.info);
    });

    testWidgets('success variant is set', (tester) async {
      await tester.pumpWidget(
        wrap(const MSToast(message: 'Done', variant: ToastVariant.success)),
      );

      final toast = tester.widget<MSToast>(find.byType(MSToast));
      expect(toast.variant, ToastVariant.success);
    });
  });

  // ---------------------------------------------------------------------------
  // ToastVariant enum stability
  // ---------------------------------------------------------------------------

  test('ToastVariant has info, success, warning, error values', () {
    expect(ToastVariant.values.length, 4);
    expect(ToastVariant.info, isNotNull);
    expect(ToastVariant.success, isNotNull);
    expect(ToastVariant.warning, isNotNull);
    expect(ToastVariant.error, isNotNull);
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Toast appends caller className onto the recipe base', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MSToast(message: 'hi', className: 'mt-10')),
    );
    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('rounded-lg'));
    expect(wDiv.className, contains('mt-10'));
  });

  // ---------------------------------------------------------------------------
  // The action
  // ---------------------------------------------------------------------------

  const phone = Size(390, 844);
  const desktop = Size(1440, 900);

  /// Mounts [toast] at the top left of a [size] surface, under the real alias
  /// map so the semantic tokens resolve the way they do in an app. Both
  /// `physicalSize` and `devicePixelRatio` are set, since setting only the first
  /// lays the tree out at the wrong logical width.
  Future<void> pumpToast(
    WidgetTester tester,
    Widget toast, {
    Size size = phone,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(
            aliases: MagicStarterTokens.defaultAliases,
            brightness: brightness,
            syncWithSystem: false,
          ),
          child: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: toast),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  MSToast undoToast({
    String message = 'Moved to Kitchen',
    ToastVariant variant = ToastVariant.info,
    VoidCallback? onAction,
    String? className,
  }) => MSToast(
    message: message,
    variant: variant,
    actionLabel: 'Undo',
    onAction: onAction ?? () {},
    className: className,
  );

  /// The tap cell around the action label.
  Finder actionCell() => find
      .ancestor(of: find.text('Undo'), matching: find.byType(WAnchor))
      .first;

  /// The toast box itself: the outermost [WDiv] of the [MSToast].
  Finder toastBox() => find
      .descendant(of: find.byType(MSToast), matching: find.byType(WDiv))
      .first;

  Color? colourOf(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).text.style?.color;

  group('toast recipe without an action', () {
    // The recipe before the action existed, copied verbatim and not derived
    // from the builder: a refactor that moved a token cannot move this with it.
    const legacyBase =
        'flex flex-row items-center gap-3 px-4 py-3 rounded-lg shadow-md';
    const legacyVariant = {
      'info': 'bg-surface border border-color-border text-fg',
      'success': 'bg-success text-white',
      'warning': 'bg-warning text-white',
      'error': 'bg-destructive text-white',
    };

    for (final variant in ToastVariant.values) {
      test('emits the previous ${variant.name} className byte for byte', () {
        expect(
          buildToastRecipe()(variants: {kToastVariantAxis: variant.name}),
          '$legacyBase ${legacyVariant[variant.name]}',
        );
      });

      testWidgets('${variant.name} renders the message in the box and no '
          'anchor', (tester) async {
        await pumpToast(tester, MSToast(message: 'Saved', variant: variant));

        final box = tester.widget<WDiv>(toastBox());

        expect(box.className, '$legacyBase ${legacyVariant[variant.name]}');
        expect(box.child, isA<WText>());
        expect(find.byType(WAnchor), findsNothing);
      });
    }
  });

  group('toast action', () {
    test('needs a label and a callback together', () {
      expect(
        () => MSToast(message: 'x', actionLabel: 'Undo'),
        throwsAssertionError,
      );
      expect(
        () => MSToast(message: 'x', onAction: () {}),
        throwsAssertionError,
      );
    });

    testWidgets('renders the message and the label', (tester) async {
      await pumpToast(tester, undoToast());

      expect(find.text('Moved to Kitchen'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('sits at the trailing side, after the message', (tester) async {
      await pumpToast(tester, undoToast());

      expect(
        tester.getRect(actionCell()).left,
        greaterThanOrEqualTo(
          tester.getRect(find.text('Moved to Kitchen')).right,
        ),
      );
      expect(
        tester.getRect(actionCell()).right,
        lessThanOrEqualTo(tester.getRect(toastBox()).right),
      );
    });

    testWidgets('a tap on the label runs onAction once', (tester) async {
      var presses = 0;
      await pumpToast(tester, undoToast(onAction: () => presses++));

      await tester.tap(find.text('Undo'));

      expect(presses, 1);
    });

    testWidgets('a tap on the message does not run it', (tester) async {
      var presses = 0;
      await pumpToast(tester, undoToast(onAction: () => presses++));

      await tester.tap(find.text('Moved to Kitchen'));

      expect(presses, 0);
    });

    testWidgets('a tap in the cell, away from the glyphs, runs it', (
      tester,
    ) async {
      var presses = 0;
      await pumpToast(tester, undoToast(onAction: () => presses++));

      final cell = tester.getRect(actionCell());
      await tester.tapAt(cell.topLeft + const Offset(2, 2));

      expect(presses, 1);
    });

    for (final entry in {'phone': phone, 'desktop': desktop}.entries) {
      testWidgets('is a 44 px hit target on a ${entry.key}', (tester) async {
        await pumpToast(tester, undoToast(), size: entry.value);

        final cell = tester.getSize(actionCell());

        expect(cell.height, greaterThanOrEqualTo(44));
        expect(cell.width, greaterThanOrEqualTo(44));
      });

      for (final variant in ToastVariant.values) {
        // The info toast has a one pixel border on each side.
        final height = variant == ToastVariant.info ? 46.0 : 44.0;

        testWidgets('keeps a one line ${variant.name} toast as tall as one '
            'without it on a ${entry.key}', (tester) async {
          await pumpToast(
            tester,
            MSToast(message: 'Moved to Kitchen', variant: variant),
            size: entry.value,
          );
          expect(tester.getSize(toastBox()).height, height);

          await pumpToast(
            tester,
            undoToast(variant: variant),
            size: entry.value,
          );

          expect(tester.getSize(toastBox()).height, height);
          expect(tester.getSize(actionCell()).height, 44);
        });
      }

      testWidgets('centres the label in the cell and the cell in the toast '
          'on a ${entry.key}', (tester) async {
        await pumpToast(tester, undoToast(), size: entry.value);

        expect(
          tester.getCenter(find.text('Undo')).dy,
          closeTo(tester.getCenter(toastBox()).dy, 1),
        );
        expect(
          tester.getCenter(actionCell()).dy,
          closeTo(tester.getCenter(toastBox()).dy, 0.01),
        );
      });
    }

    testWidgets('meets the iOS tap target on a phone', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpToast(tester, undoToast());

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('names the action for assistive technology', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpToast(tester, undoToast());

      final node = tester.getSemantics(actionCell());
      final data = node.getSemanticsData();

      expect(data.label, 'Undo');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(find.bySemanticsLabel('Undo'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a semantic tap runs onAction', (tester) async {
      final handle = tester.ensureSemantics();
      var presses = 0;
      await pumpToast(tester, undoToast(onAction: () => presses++));

      tester.semantics.tap(find.semantics.byLabel('Undo'));
      await tester.pump();

      expect(presses, 1);
      handle.dispose();
    });

    testWidgets('Enter on the focused action runs onAction', (tester) async {
      var presses = 0;
      await pumpToast(tester, undoToast(onAction: () => presses++));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(presses, 1);
    });

    testWidgets('Space on the focused action runs onAction too', (
      tester,
    ) async {
      var presses = 0;
      await pumpToast(tester, undoToast(onAction: () => presses++));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(presses, 1);
    });

    testWidgets('appends a caller className after the action modifiers', (
      tester,
    ) async {
      await pumpToast(tester, undoToast(className: 'mt-10'));

      final box = tester.widget<WDiv>(toastBox());

      expect(box.className, startsWith('flex flex-row items-center gap-3'));
      expect(box.className, endsWith(' mt-10'));
    });
  });

  group('toast action with a long message', () {
    const long =
        'Moved Dishwasher Tablets, Rinse Aid and Descaler to the Kitchen '
        'cupboard above the oven and the pantry shelf';

    for (final entry in {'phone': phone, 'desktop': desktop}.entries) {
      testWidgets('wraps the message and keeps the action whole on a '
          '${entry.key}', (tester) async {
        await pumpToast(tester, undoToast(), size: entry.value);
        final shortCell = tester.getSize(actionCell());

        await pumpToast(tester, undoToast(message: long), size: entry.value);

        expect(tester.takeException(), isNull);
        expect(tester.getSize(actionCell()), shortCell);
        expect(
          tester.getRect(actionCell()).right,
          lessThanOrEqualTo(tester.getRect(toastBox()).right),
        );
        expect(
          tester.getRect(find.text(long)).right,
          lessThanOrEqualTo(tester.getRect(actionCell()).left),
        );
        expect(
          tester.getSize(find.text(long)).height,
          greaterThan(20),
          reason: 'the message wraps onto more lines',
        );
      });
    }

    testWidgets('centres the action against a message of several lines', (
      tester,
    ) async {
      await pumpToast(tester, undoToast(message: long));

      expect(
        tester.getCenter(actionCell()).dy,
        closeTo(tester.getCenter(toastBox()).dy, 0.01),
      );
    });

    testWidgets('pads a wrapped message as it pads a short one', (
      tester,
    ) async {
      // The success toast, which has no border to add to the padding.
      await pumpToast(
        tester,
        undoToast(message: long, variant: ToastVariant.success),
      );

      final message = tester.getRect(find.text(long));
      final box = tester.getRect(toastBox());

      expect(message.top - box.top, 12);
      expect(box.bottom - message.bottom, 12);
      expect(message.left - box.left, 16);
      expect(
        box.right - tester.getRect(actionCell()).right,
        8,
        reason: 'the cell has its own px-2 beside the box pr-2',
      );
    });
  });

  group('toast action by variant and brightness', () {
    // What the toast paints on, and so what the label has to read against.
    for (final brightness in Brightness.values) {
      for (final variant in ToastVariant.values) {
        final label = '${variant.name} ${brightness.name}';

        testWidgets('paints the label in the tone of the message, $label', (
          tester,
        ) async {
          await pumpToast(
            tester,
            undoToast(variant: variant),
            brightness: brightness,
          );

          final windTheme = WindThemeData();
          final expected = variant == ToastVariant.info
              ? windTheme.getColor('primary', 500)
              : const Color(0xFFFFFFFF);

          expect(colourOf(tester, 'Undo'), expected);
          if (variant != ToastVariant.info) {
            expect(
              colourOf(tester, 'Undo'),
              colourOf(tester, 'Moved to Kitchen'),
            );
          }
        });

        testWidgets('paints the focus ring inside the toast on Tab, $label', (
          tester,
        ) async {
          await pumpToast(
            tester,
            undoToast(variant: variant),
            brightness: brightness,
          );
          final ring = find.descendant(
            of: find.byType(MSToast),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.position == DecorationPosition.foreground &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).border != null,
            ),
          );
          expect(ring, findsNothing);

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();

          expect(ring, findsOneWidget);
          final border =
              (tester.widget<DecoratedBox>(ring).decoration as BoxDecoration)
                      .border!
                  as Border;
          final windTheme = WindThemeData();
          final expected = variant == ToastVariant.info
              ? windTheme.getColor(
                  'primary',
                  brightness == Brightness.dark ? 400 : 500,
                )
              : const Color(0xFFFFFFFF);

          expect(border.top.color, expected);
          expect(border.top.strokeAlign, BorderSide.strokeAlignInside);
          expect(
            tester.getRect(ring),
            tester.getRect(actionCell()),
            reason: 'the ring is the cell, so it stays inside the toast',
          );
        });

        testWidgets('fills the cell under the pointer, $label', (tester) async {
          await pumpToast(
            tester,
            undoToast(variant: variant),
            brightness: brightness,
          );

          // Wind paints a fill as a background DecoratedBox around the cell.
          Color? fill() => tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: actionCell(),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .where((box) => box.position == DecorationPosition.background)
              .map((box) => box.decoration)
              .whereType<BoxDecoration>()
              .map((decoration) => decoration.color)
              .nonNulls
              .firstOrNull;

          expect(fill(), isNull);

          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          await mouse.moveTo(tester.getCenter(actionCell()));
          await tester.pumpAndSettle();

          final hovered = fill();

          expect(hovered, isNotNull);
          if (variant != ToastVariant.info) {
            // White over a coloured fill, quiet enough to leave the label
            // white on it readable.
            expect(hovered!.r, 1);
            expect(hovered.g, 1);
            expect(hovered.b, 1);
            expect(hovered.a, closeTo(0.15, 0.01));
          }
        });
      }
    }
  });

  testWidgets('the toast preview shows an action on every variant', (
    tester,
  ) async {
    // On a desktop surface: the test font is wider than a real one, and the
    // message-only rows of the matrix do not wrap on a phone.
    await pumpToast(
      tester,
      const SingleChildScrollView(child: ToastPreview()),
      size: desktop,
    );

    expect(find.byType(MSToast), findsNWidgets(ToastVariant.values.length * 2));
    expect(find.text('Undo'), findsNWidgets(ToastVariant.values.length));
    expect(tester.takeException(), isNull);
  });
}
