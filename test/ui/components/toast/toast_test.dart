import 'dart:math' show max, min;
import 'dart:ui' as ui;

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
    Map<String, String> aliases = MagicStarterTokens.defaultAliases,
    ui.TextDirection textDirection = ui.TextDirection.ltr,
    double textScale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(
            aliases: aliases,
            brightness: brightness,
            syncWithSystem: false,
          ),
          child: Scaffold(
            body: Directionality(
              textDirection: textDirection,
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: Align(alignment: Alignment.topLeft, child: toast),
                ),
              ),
            ),
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

  /// The size and weight the action label paints with.
  (double?, FontWeight?) paintedLabel(WidgetTester tester) {
    final style = tester
        .renderObject<RenderParagraph>(find.text('Undo'))
        .text
        .style;

    return (style?.fontSize, style?.fontWeight);
  }

  Color? colourOf(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).text.style?.color;

  group('toast recipe without an action', () {
    // The recipe before the action existed, copied verbatim and not derived
    // from the builder: a refactor that moved a token cannot move this with it.
    const legacyBase =
        'flex flex-row items-center gap-3 px-4 py-3 rounded-lg shadow-md';
    // `info` is the previous string byte for byte. The three toned variants
    // kept their fill and swapped the literal `text-white` for the on-colour
    // role of the fill (see the contrast group below); with no theme to define a
    // role the string carries the role's fallback pair instead.
    const legacyVariant = {
      'info': 'bg-surface border border-color-border text-fg',
      'success': 'bg-success text-gray-950 dark:text-gray-950',
      'warning': 'bg-warning text-gray-950 dark:text-gray-950',
      'error': 'bg-destructive text-white dark:text-white',
    };
    // Under the stock alias map, which defines `text-on-destructive` and no
    // on-colour role for the success and warning fills: those two measure the
    // fill they paint and take the better of white and near-black, which on the
    // stock green and amber is the near-black.
    const stockVariant = {
      'info': 'bg-surface border border-color-border text-fg',
      'success': 'bg-success text-gray-950',
      'warning': 'bg-warning text-gray-950',
      'error': 'bg-destructive text-on-destructive',
    };

    for (final variant in ToastVariant.values) {
      test('emits the ${variant.name} className, base unchanged', () {
        expect(
          buildToastRecipe()(variants: {kToastVariantAxis: variant.name}),
          '$legacyBase ${legacyVariant[variant.name]}',
        );
      });

      testWidgets('${variant.name} renders the message in the box and no '
          'anchor', (tester) async {
        await pumpToast(tester, MSToast(message: 'Saved', variant: variant));

        final box = tester.widget<WDiv>(toastBox());

        expect(box.className, '$legacyBase ${stockVariant[variant.name]}');
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

  group('toast message class', () {
    // What a host with a 15 on 20 body sets: the default is 14 medium.
    const hostMessage = 'text-[15px] leading-5 font-normal';

    TextStyle? messageStyle(WidgetTester tester) =>
        tester.renderObject<RenderParagraph>(find.text('Saved')).text.style;

    double lineOf(TextStyle? style) => style!.fontSize! * style.height!;

    WText messageWidget(WidgetTester tester) => tester.widget<WText>(
      find.byWidgetPredicate((w) => w is WText && w.data == 'Saved'),
    );

    Widget withAction({String? messageClassName}) => MSToast(
      message: 'Saved',
      actionLabel: 'Undo',
      onAction: () {},
      messageClassName: messageClassName,
    );

    Widget messageOnly({String? messageClassName}) =>
        MSToast(message: 'Saved', messageClassName: messageClassName);

    testWidgets('a toast without one keeps the default message class', (
      tester,
    ) async {
      await pumpToast(tester, messageOnly());
      expect(messageWidget(tester).className, 'text-sm font-medium');

      await pumpToast(tester, withAction());
      expect(messageWidget(tester).className, 'text-sm font-medium');
    });

    testWidgets('an empty class adds nothing to the default', (tester) async {
      await pumpToast(tester, messageOnly(messageClassName: ''));

      expect(messageWidget(tester).className, 'text-sm font-medium');
    });

    testWidgets('is appended after the default message class', (tester) async {
      await pumpToast(tester, messageOnly(messageClassName: hostMessage));
      expect(
        messageWidget(tester).className,
        'text-sm font-medium $hostMessage',
      );

      await pumpToast(tester, withAction(messageClassName: hostMessage));
      expect(
        messageWidget(tester).className,
        'text-sm font-medium $hostMessage',
      );
    });

    for (final brightness in Brightness.values) {
      testWidgets('the default paints 14 on 20 at weight 500, '
          '${brightness.name}', (tester) async {
        await pumpToast(tester, messageOnly(), brightness: brightness);
        final style = messageStyle(tester);

        expect(style?.fontSize, 14);
        expect(style?.fontWeight, FontWeight.w500);
      });

      for (final entry in {
        'message only': false,
        'with an action': true,
      }.entries) {
        testWidgets('a host class sets 15 on 20 at weight 400, ${entry.key}, '
            '${brightness.name}', (tester) async {
          await pumpToast(
            tester,
            entry.value
                ? withAction(messageClassName: hostMessage)
                : messageOnly(messageClassName: hostMessage),
            brightness: brightness,
          );
          final style = messageStyle(tester);

          expect(style?.fontSize, 15);
          expect(lineOf(style), closeTo(20, 0.01));
          expect(style?.fontWeight, FontWeight.w400);
          expect(
            tester.getSize(find.text('Saved')).height,
            closeTo(20, 0.01),
            reason: 'the laid out line is the 20 px the class asks for',
          );
        });
      }

      testWidgets('leaves the colour of the message to the toast, '
          '${brightness.name}', (tester) async {
        await pumpToast(tester, messageOnly(), brightness: brightness);
        final plain = colourOf(tester, 'Saved');

        await pumpToast(
          tester,
          messageOnly(messageClassName: hostMessage),
          brightness: brightness,
        );

        expect(colourOf(tester, 'Saved'), plain);
      });
    }

    testWidgets('a host class changes the message and not the action', (
      tester,
    ) async {
      await pumpToast(tester, withAction());
      final label = paintedLabel(tester);

      await pumpToast(tester, withAction(messageClassName: hostMessage));

      expect(paintedLabel(tester), label);
      expect(messageStyle(tester)?.fontSize, 15);
    });
  });

  group('toast action at a large text size', () {
    for (final scale in [1.0, 2.0, 2.5]) {
      testWidgets('lays out without an overflow at a text scale of $scale', (
        tester,
      ) async {
        await pumpToast(tester, undoToast(), textScale: scale);

        expect(tester.takeException(), isNull);
      });

      testWidgets('keeps the label inside the cell and the cell inside the '
          'toast at a text scale of $scale', (tester) async {
        await pumpToast(
          tester,
          undoToast(variant: ToastVariant.success),
          textScale: scale,
        );

        final label = tester.getRect(find.text('Undo'));
        final cell = tester.getRect(actionCell());
        final box = tester.getRect(toastBox());

        expect(cell.height, greaterThanOrEqualTo(44));
        expect(cell.top, lessThanOrEqualTo(label.top));
        expect(cell.bottom, greaterThanOrEqualTo(label.bottom));
        expect(box.top, lessThanOrEqualTo(cell.top));
        expect(box.bottom, greaterThanOrEqualTo(cell.bottom));
        expect(cell.center.dy, closeTo(label.center.dy, 0.01));
      });
    }

    testWidgets('the cell is exactly 44 tall at the default size', (
      tester,
    ) async {
      await pumpToast(tester, undoToast());

      expect(tester.getSize(actionCell()).height, 44);
    });

    testWidgets('the cell grows to the label and no further at 2.5', (
      tester,
    ) async {
      await pumpToast(
        tester,
        undoToast(variant: ToastVariant.success),
        textScale: 2.5,
      );

      // A cell that took the whole height an overlay offers it (the bounded
      // 844 px of the surface) would be far taller than its label.
      expect(
        tester.getSize(actionCell()).height,
        lessThan(tester.getSize(find.text('Undo')).height + 1),
      );
      expect(tester.getSize(toastBox()).height, lessThan(300));
    });
  });

  group('toast action in a right to left locale', () {
    testWidgets('pads the message and the label the same from their edges', (
      tester,
    ) async {
      // The success toast, which has no border to add to the padding.
      final toast = undoToast(variant: ToastVariant.success);

      await pumpToast(tester, toast);
      final ltr = (
        start:
            tester.getRect(find.text('Moved to Kitchen')).left -
            tester.getRect(toastBox()).left,
        end:
            tester.getRect(toastBox()).right -
            tester.getRect(find.text('Undo')).right,
      );

      await pumpToast(tester, toast, textDirection: ui.TextDirection.rtl);
      final box = tester.getRect(toastBox());
      final rtl = (
        start: box.right - tester.getRect(find.text('Moved to Kitchen')).right,
        end: tester.getRect(find.text('Undo')).left - box.left,
      );

      expect(ltr.start, 16);
      expect(ltr.end, closeTo(16, 0.01));
      expect(rtl.start, ltr.start, reason: 'the message edge mirrors');
      expect(rtl.end, closeTo(ltr.end, 0.01), reason: 'the label edge mirrors');
    });

    testWidgets('puts the action at the leading edge of the right to left '
        'toast', (tester) async {
      await pumpToast(tester, undoToast(), textDirection: ui.TextDirection.rtl);

      expect(
        tester.getRect(actionCell()).right,
        lessThanOrEqualTo(tester.getRect(find.text('Moved to Kitchen')).left),
      );
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
          final expected = switch (variant) {
            ToastVariant.info => windTheme.getColor('primary', 500),
            // The stock alias map defines no on-colour role for the success
            // and warning fills, so those two read the fallback.
            ToastVariant.success ||
            ToastVariant.warning => windTheme.getColor('gray', 950),
            ToastVariant.error => const Color(0xFFFFFFFF),
          };

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
          // The ring of a toned variant is the colour of its label, which is
          // the colour that has to read against the fill.
          final expected = variant == ToastVariant.info
              ? windTheme.getColor(
                  'primary',
                  brightness == Brightness.dark ? 400 : 500,
                )
              : colourOf(tester, 'Undo');

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
            // The label colour over its own fill, quiet enough to leave the
            // label readable on it.
            final label = colourOf(tester, 'Undo')!;
            expect(hovered!.r, closeTo(label.r, 0.01));
            expect(hovered.g, closeTo(label.g, 0.01));
            expect(hovered.b, closeTo(label.b, 0.01));
            expect(hovered.a, closeTo(0.15, 0.01));
          }
        });
      }
    }
  });

  // The fill of a toned toast is the host's, light in some dark themes, so a
  // literal white label can fail on it. The label, the message and the ring read
  // the on-colour role of the fill, and the numbers below are measured off what
  // is painted, from the roles the test defines.
  group('toast contrast', () {
    /// WCAG contrast ratio of two opaque colours.
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();

      return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
    }

    /// The fill the toast paints behind its message.
    Color fillOf(WidgetTester tester) => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(MSToast),
            matching: find.byType(DecoratedBox),
          ),
        )
        .where((box) => box.position == DecorationPosition.background)
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .nonNulls
        .first;

    /// The colour of the focus ring on the action, after Tab.
    Future<Color> ringOf(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

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

      return ((tester.widget<DecoratedBox>(ring).decoration as BoxDecoration)
                  .border!
              as Border)
          .top
          .color;
    }

    // A host whose dark fills are light, so its on-colour roles flip to dark
    // text there. These are the host's roles; the numbers are measured below.
    final hostAliases = <String, String>{
      ...MagicStarterTokens.defaultAliases,
      'bg-success': 'bg-[#2E7D4F] dark:bg-[#8FD1A3]',
      'text-on-success': 'text-[#FFFFFF] dark:text-[#0B2A18]',
      'bg-warning': 'bg-[#9A5B00] dark:bg-[#F2B65C]',
      'text-on-warning': 'text-[#FFFFFF] dark:text-[#2B1A00]',
      'bg-destructive': 'bg-[#C62828] dark:bg-[#FF8A80]',
      'text-on-destructive': 'text-[#FFFFFF] dark:text-[#3B0A07]',
    };

    final toned = ToastVariant.values.where((v) => v != ToastVariant.info);

    for (final brightness in Brightness.values) {
      for (final variant in toned) {
        final label = '${variant.name} ${brightness.name}';

        testWidgets('a host theme with the roles: message and label read the '
            'fill at 4.5:1 and the ring at 3:1, $label', (tester) async {
          await pumpToast(
            tester,
            undoToast(variant: variant),
            brightness: brightness,
            aliases: hostAliases,
          );

          final fill = fillOf(tester);
          final message = colourOf(tester, 'Moved to Kitchen')!;
          final action = colourOf(tester, 'Undo')!;
          final ring = await ringOf(tester);

          expect(contrast(message, fill), greaterThanOrEqualTo(4.5));
          expect(contrast(action, fill), greaterThanOrEqualTo(4.5));
          expect(contrast(ring, fill), greaterThanOrEqualTo(3));
        });
      }
    }

    // The stock alias map defines no on-colour role for the success and warning
    // fills, so these read the fallbacks, which are chosen to read on the stock
    // fills. The error variant reads `text-on-destructive` (white): 4.8:1 on the
    // stock light fill, but 3.8:1 on the stock dark one (red-500), which is the
    // alias map's own pairing and is also what a destructive button paints.
    for (final brightness in Brightness.values) {
      for (final variant in [ToastVariant.success, ToastVariant.warning]) {
        testWidgets('the stock aliases: ${variant.name} ${brightness.name} '
            'reads at 4.5:1 through the fallback role', (tester) async {
          await pumpToast(
            tester,
            undoToast(variant: variant),
            brightness: brightness,
          );

          final fill = fillOf(tester);

          expect(
            contrast(colourOf(tester, 'Moved to Kitchen')!, fill),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(colourOf(tester, 'Undo')!, fill),
            greaterThanOrEqualTo(4.5),
          );
          expect(contrast(await ringOf(tester), fill), greaterThanOrEqualTo(3));
        });
      }
    }

    // A host that redefines the fills and defines no on-colour role for them.
    // The fallback cannot assume the stock light fill: it measures the fill the
    // variant paints in the current mode and takes the better of white and the
    // near-black. These are depools-shaped: a mid-dark green in light mode and
    // a pale one in dark, which is where near-black alone drops to 3.1:1.
    final undefinedRoles = <String, String>{
      ...MagicStarterTokens.defaultAliases,
      'bg-success': 'bg-[#2E6B45] dark:bg-[#8FD1A3]',
      'bg-warning': 'bg-[#9A5B00] dark:bg-[#F2B65C]',
    };

    for (final brightness in Brightness.values) {
      for (final variant in [ToastVariant.success, ToastVariant.warning]) {
        final label = '${variant.name} ${brightness.name}';

        testWidgets('undefined role on host fills: the fallback is chosen by '
            'contrast and clears 4.5:1 and 3:1, $label', (tester) async {
          await pumpToast(
            tester,
            undoToast(variant: variant),
            brightness: brightness,
            aliases: undefinedRoles,
          );

          final fill = fillOf(tester);
          final message = colourOf(tester, 'Moved to Kitchen')!;
          final action = colourOf(tester, 'Undo')!;

          expect(contrast(message, fill), greaterThanOrEqualTo(4.5));
          expect(contrast(action, fill), greaterThanOrEqualTo(4.5));
          expect(contrast(await ringOf(tester), fill), greaterThanOrEqualTo(3));
        });
      }
    }

    testWidgets(
      'undefined role: white on the dark fill, near-black on the pale '
      'one, whichever reads better',
      (tester) async {
        await pumpToast(
          tester,
          undoToast(variant: ToastVariant.success),
          aliases: undefinedRoles,
        );
        expect(colourOf(tester, 'Moved to Kitchen'), const Color(0xFFFFFFFF));

        await pumpToast(
          tester,
          undoToast(variant: ToastVariant.success),
          brightness: Brightness.dark,
          aliases: undefinedRoles,
        );
        expect(
          colourOf(tester, 'Moved to Kitchen'),
          WindThemeData().getColor('gray', 950),
        );
      },
    );

    for (final brightness in Brightness.values) {
      for (final variant in [ToastVariant.success, ToastVariant.warning]) {
        testWidgets('stock fills keep the near-black pair, ${variant.name} '
            '${brightness.name}', (tester) async {
          await pumpToast(
            tester,
            undoToast(variant: variant),
            brightness: brightness,
          );

          expect(
            colourOf(tester, 'Moved to Kitchen'),
            WindThemeData().getColor('gray', 950),
          );
          expect(
            colourOf(tester, 'Undo'),
            WindThemeData().getColor('gray', 950),
          );
        });
      }
    }

    for (final brightness in Brightness.values) {
      testWidgets('a role the host defines is used as it is, even where '
          'another colour would read better, ${brightness.name}', (
        tester,
      ) async {
        await pumpToast(
          tester,
          undoToast(variant: ToastVariant.success),
          brightness: brightness,
          aliases: <String, String>{
            ...undefinedRoles,
            // Poor on both fills; the host's word is final.
            'text-on-success': 'text-[#123456] dark:text-[#123456]',
          },
        );

        expect(colourOf(tester, 'Moved to Kitchen'), const Color(0xFF123456));
        expect(colourOf(tester, 'Undo'), const Color(0xFF123456));
      });
    }

    testWidgets('a fill the theme cannot resolve falls back to the role pair', (
      tester,
    ) async {
      // No alias map at all: `bg-success` resolves to nothing, so there is no
      // fill to measure and the role's own fallback applies.
      await pumpToast(
        tester,
        undoToast(variant: ToastVariant.success),
        aliases: const <String, String>{},
      );

      expect(
        colourOf(tester, 'Moved to Kitchen'),
        WindThemeData().getColor('gray', 950),
      );
    });

    testWidgets('a message-only toned toast reads the role too', (
      tester,
    ) async {
      await pumpToast(
        tester,
        const MSToast(message: 'Saved', variant: ToastVariant.success),
        brightness: Brightness.dark,
        aliases: hostAliases,
      );

      expect(
        contrast(colourOf(tester, 'Saved')!, fillOf(tester)),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('the info variant is untouched: text-fg on bg-surface', (
      tester,
    ) async {
      await pumpToast(tester, undoToast(), brightness: Brightness.dark);

      expect(tester.widget<WDiv>(toastBox()).className, contains('text-fg'));
      expect(
        contrast(colourOf(tester, 'Moved to Kitchen')!, fillOf(tester)),
        greaterThanOrEqualTo(4.5),
      );
    });
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
