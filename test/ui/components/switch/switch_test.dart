import 'package:flutter/material.dart' hide Switch;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/switch/switch.preview.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
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
  // Recipe variant-class assertions
  // ---------------------------------------------------------------------------

  group('switch recipe', () {
    test('track recipe emits rounded-full token', () {
      final cls = switchTrackRecipe();
      expect(cls, contains('rounded-full'));
    });

    test('track recipe emits checked: state prefix token for bg-primary', () {
      final cls = switchTrackRecipe();
      expect(cls, contains('checked:bg-primary'));
    });

    test('thumb recipe emits rounded-full token', () {
      final cls = switchThumbRecipe();
      expect(cls, contains('rounded-full'));
    });

    test('track recipe carries a focus ring with its dark pair', () {
      final cls = switchTrackRecipe();
      expect(cls, contains('focus:ring-2'));
      expect(cls, contains('focus:ring-primary-500'));
      expect(cls, contains('dark:focus:ring-primary-400'));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Switch renders a WSwitch', (tester) async {
    await tester.pumpWidget(wrap(MSSwitch(value: false, onChanged: (_) {})));
    expect(find.byType(WSwitch), findsOneWidget);
  });

  testWidgets('Switch reflects value prop on WSwitch', (tester) async {
    await tester.pumpWidget(wrap(MSSwitch(value: true, onChanged: (_) {})));
    final widget = tester.widget<WSwitch>(find.byType(WSwitch));
    expect(widget.value, isTrue);
  });

  testWidgets('Switch fires onChanged when tapped', (tester) async {
    bool? newValue;
    await tester.pumpWidget(
      wrap(MSSwitch(value: false, onChanged: (v) => newValue = v)),
    );
    await tester.tap(find.byType(WSwitch));
    await tester.pump();
    expect(newValue, isTrue);
  });

  testWidgets('Switch applies track className with bg-surface-container-high', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(MSSwitch(value: false, onChanged: (_) {})));
    final widget = tester.widget<WSwitch>(find.byType(WSwitch));
    expect(widget.className, contains('bg-surface-container-high'));
  });

  testWidgets('Switch preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const SwitchPreview()));
    await tester.pump();
    expect(find.byType(SwitchPreview), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Switch appends caller className onto track and thumb recipes', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MSSwitch(
          value: false,
          onChanged: (_) {},
          className: 'mt-10',
          thumbClassName: 'mb-10',
        ),
      ),
    );
    final widget = tester.widget<WSwitch>(find.byType(WSwitch));
    expect(widget.className, contains('rounded-full'));
    expect(widget.className, contains('mt-10'));
    expect(widget.thumbClassName, contains('bg-surface'));
    expect(widget.thumbClassName, contains('mb-10'));
  });

  // ---------------------------------------------------------------------------
  // Keyboard focus ring
  // ---------------------------------------------------------------------------

  group('Switch keyboard focus', () {
    /// The ring is an outline wind paints in a foreground DecoratedBox, so the
    /// resolved colour is read off the border rather than the className string.
    Finder ringOutline() => find.descendant(
      of: find.byType(MSSwitch),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    );

    Widget toggle({bool disabled = false}) => Center(
      child: MSSwitch(value: false, onChanged: (_) {}, disabled: disabled),
    );

    testWidgets('paints no ring while the switch is at rest', (tester) async {
      await tester.pumpWidget(wrap(toggle()));

      expect(ringOutline(), findsNothing);
    });

    testWidgets('Tab onto the switch paints the primary ring', (tester) async {
      await tester.pumpWidget(wrap(toggle()));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(ringOutline(), findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(ringOutline()).decoration
              as BoxDecoration;
      expect(
        (decoration.border! as Border).top.color,
        WindThemeData().getColor('primary', 500),
      );
    });

    testWidgets('a tap does not paint the ring', (tester) async {
      await tester.pumpWidget(wrap(toggle()));

      await tester.tap(find.byType(WSwitch));
      await tester.pumpAndSettle();

      expect(ringOutline(), findsNothing);
    });

    testWidgets('a disabled switch is skipped by Tab and paints no ring', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(toggle(disabled: true)));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(ringOutline(), findsNothing);
    });

    testWidgets('the ring reserves its space, so focus shifts nothing', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(toggle()));
      final before = tester.getRect(find.byType(MSSwitch));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byType(MSSwitch)), before);
    });
  });

  // ---------------------------------------------------------------------------
  // Tap target and visible label
  // ---------------------------------------------------------------------------

  group('Switch tap target', () {
    /// Mounts [widget] on a 390x844 logical-pixel phone surface. Both
    /// `physicalSize` and `devicePixelRatio` are set, since setting only the
    /// first lays the tree out at the wrong logical width.
    Future<void> pumpAt(WidgetTester tester, Size size, Widget widget) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = size * 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(Center(child: widget)));
      await tester.pumpAndSettle();
    }

    const phone = Size(390, 844);
    const desktop = Size(1280, 800);

    testWidgets('an unlabelled switch meets the iOS tap target on a phone', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAt(tester, phone, MSSwitch(value: false, onChanged: (_) {}));

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a labelled switch meets the iOS tap target on a phone', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        phone,
        MSSwitch(value: true, onChanged: (_) {}, label: 'Product updates'),
      );

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the 24 px track is still painted at 24 px on a phone', (
      tester,
    ) async {
      await pumpAt(tester, phone, MSSwitch(value: false, onChanged: (_) {}));

      expect(tester.getSize(find.byType(WSwitch)), const Size(44, 24));
    });

    testWidgets('the area around the track toggles it on a phone', (
      tester,
    ) async {
      bool? changed;
      await pumpAt(
        tester,
        phone,
        MSSwitch(value: false, onChanged: (v) => changed = v),
      );

      final track = tester.getRect(find.byType(WSwitch));
      await tester.tapAt(track.topCenter - const Offset(0, 8));

      expect(changed, isTrue);
    });

    testWidgets('without a label it renders exactly as before on desktop', (
      tester,
    ) async {
      await pumpAt(tester, desktop, MSSwitch(value: false, onChanged: (_) {}));

      expect(tester.getSize(find.byType(MSSwitch)), const Size(44, 24));
    });

    testWidgets('tapping the visible label toggles the switch', (tester) async {
      bool? changed;
      await pumpAt(
        tester,
        phone,
        MSSwitch(
          value: false,
          onChanged: (v) => changed = v,
          label: 'Product updates',
        ),
      );

      await tester.tap(find.text('Product updates'));

      expect(changed, isTrue);
    });

    testWidgets('tapping the track of a labelled switch toggles it once', (
      tester,
    ) async {
      var calls = 0;
      await pumpAt(
        tester,
        phone,
        MSSwitch(value: false, onChanged: (_) => calls++, label: 'Updates'),
      );

      await tester.tap(find.byType(WSwitch));

      expect(calls, 1);
    });

    testWidgets('a disabled switch ignores a tap on its label', (tester) async {
      bool? changed;
      await pumpAt(
        tester,
        phone,
        MSSwitch(
          value: false,
          onChanged: (v) => changed = v,
          disabled: true,
          label: 'Product updates',
        ),
      );

      await tester.tap(find.text('Product updates'));

      expect(changed, isNull);
    });

    testWidgets('the label is the switch name, announced once', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        phone,
        MSSwitch(value: true, onChanged: (_) {}, label: 'Product updates'),
      );

      expect(
        tester.getSemantics(find.byType(MSSwitch)),
        isSemantics(label: 'Product updates', hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('a long label wraps instead of overflowing', (tester) async {
      await pumpAt(
        tester,
        phone,
        MSSwitch(
          value: false,
          onChanged: (_) {},
          label:
              'Send me a summary of everything that happened on my '
              'monitors while I was away, every single morning',
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a labelled switch lays out in a row of unbounded width', (
      tester,
    ) async {
      // A settings row's trailing slot is a Row child without a flex share,
      // so the switch inside it is measured with an unbounded width.
      await pumpAt(
        tester,
        phone,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MSSwitch(value: true, onChanged: (_) {}, label: 'Weekly digest'),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Weekly digest'), findsOneWidget);
      expect(tester.getSize(find.byType(MSSwitch)).height, 44);
    });

    testWidgets('a labelled switch reports its intrinsic size', (tester) async {
      // IntrinsicHeight, IntrinsicWidth and an IntrinsicColumnWidth table all
      // ask the switch to measure itself before it is laid out.
      await pumpAt(
        tester,
        phone,
        IntrinsicWidth(
          child: IntrinsicHeight(
            child: MSSwitch(
              value: true,
              onChanged: (_) {},
              label: 'Weekly digest',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final Size size = tester.getSize(find.byType(MSSwitch));
      expect(size.height, 44);
      expect(
        size.width,
        tester.getSize(find.byType(WSwitch)).width +
            12 +
            tester.getSize(find.text('Weekly digest')).width,
      );
    });

    testWidgets('a long label still wraps in a bounded column', (tester) async {
      const String long =
          'Send me a summary of everything that happened on my '
          'monitors while I was away, every single morning';
      await pumpAt(
        tester,
        phone,
        SizedBox(
          width: 240,
          child: MSSwitch(value: false, onChanged: (_) {}, label: long),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(MSSwitch)).width,
        lessThanOrEqualTo(240),
      );
      expect(tester.getSize(find.text(long)).height, greaterThan(20));
    });
  });
}
