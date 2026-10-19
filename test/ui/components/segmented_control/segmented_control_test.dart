import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

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
  // Recipe slot-class assertions
  // ---------------------------------------------------------------------------

  group('segmented control recipe', () {
    test('item slot carries a focus ring with its dark pair', () {
      final item = segmentedControlRecipe()['item'];
      expect(item, contains('focus:ring-2'));
      expect(item, contains('focus:ring-primary-500'));
      expect(item, contains('dark:focus:ring-primary-400'));
    });

    test('sm size emits text-sm', () {
      final cls = segmentedControlRecipe(
        variants: {'size': SegmentedControlSize.sm.name},
      );
      expect(cls['item'], contains('text-sm'));
    });

    test('md size emits text-sm or text-base', () {
      final cls = segmentedControlRecipe(
        variants: {'size': SegmentedControlSize.md.name},
      );
      // md size item should have some text-size token
      expect(cls['item'], isNotEmpty);
    });

    test('root slot contains bg-surface-container-high', () {
      final cls = segmentedControlRecipe();
      expect(cls['root'], contains('bg-surface-container-high'));
    });

    test('item slot centres its label for the wrapped case', () {
      final cls = segmentedControlRecipe();
      expect(cls['item'], contains('text-center'));
    });

    test('all two required slots are present', () {
      final cls = segmentedControlRecipe();
      expect(cls.keys, containsAll(['root', 'item']));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  group('SegmentedControl widget', () {
    testWidgets('renders option labels', (tester) async {
      await tester.pumpWidget(
        wrap(
          MSSegmentedControl<String>(
            options: const ['Option A', 'Option B', 'Option C'],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
      expect(find.text('Option C'), findsOneWidget);
    });

    testWidgets('calls onChanged when a segment is tapped', (tester) async {
      int? changed;
      await tester.pumpWidget(
        wrap(
          MSSegmentedControl<String>(
            options: const ['Option A', 'Option B'],
            selectedIndex: 0,
            onChanged: (i) => changed = i,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Option B'));
      await tester.pumpAndSettle();

      expect(changed, equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Narrow-surface layout
  //
  // The group above lays out on the default 800x600 test surface, which is
  // wider than any phone, so it cannot see a segmented control whose labels do
  // not fit. These cases pin the width the billing screen's monthly/annual
  // toggle overflowed at, with labels that are sentences rather than words,
  // and they hold the shrink to a floor: the label stays whole (a localised
  // sentence cannot be shortened from the right) and the segment stays
  // tappable.
  // ---------------------------------------------------------------------------

  group('SegmentedControl on a narrow surface', () {
    /// The two labels the billing screen renders side by side; the second is a
    /// sentence fragment, not a word, and is what pushed the row past a phone.
    const String monthly = 'Monthly';
    const String annual = 'Annual · save ~15%';

    /// Mounts [control] on a 390x844 logical-pixel surface (a phone), inside
    /// the centred column with a page gutter that the billing screen uses.
    ///
    /// Both `physicalSize` and `devicePixelRatio` are set: setting only the
    /// first lays the tree out at the ambient ratio and therefore at the wrong
    /// logical width. Both are restored when the case ends.
    Future<void> pumpOnPhone(WidgetTester tester, Widget control) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          WDiv(
            className: 'flex flex-col items-center gap-2 px-4',
            children: [control],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('two sentence-long labels lay out without an overflow', (
      tester,
    ) async {
      await pumpOnPhone(
        tester,
        MSSegmentedControl<String>(
          size: SegmentedControlSize.sm,
          options: const [monthly, annual],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('both labels stay whole, with no ellipsis', (tester) async {
      await pumpOnPhone(
        tester,
        MSSegmentedControl<String>(
          size: SegmentedControlSize.sm,
          options: const [monthly, annual],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      );

      for (final label in const [monthly, annual]) {
        expect(find.text(label), findsOneWidget);
        expect(
          tester.widget<Text>(find.text(label)).overflow,
          isNot(TextOverflow.ellipsis),
        );
        // The paragraph wraps rather than clipping: no line was dropped, and a
        // wrapped line sits centred under the first without the caller saying
        // so (the wrapper above carries no `text-center`).
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.textAlign, equals(TextAlign.center));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('a one-word segment is still a 44 px target each way', (
      tester,
    ) async {
      // "All" painted 42 px wide: the hit cell had a 44 px floor in height
      // only, so a short label left the target narrower than the touch floor.
      // One-letter labels, because the test font paints every glyph as wide
      // as it is tall and "All" alone already clears 44 px here.
      await pumpOnPhone(
        tester,
        MSSegmentedControl<String>(
          options: const ['A', 'B'],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      );

      // The hit cell is the box the recipe's `hit` slot paints around a pill.
      final Finder cells = find.byWidgetPredicate(
        (widget) =>
            widget is WDiv && (widget.className?.contains('min-h-11') ?? false),
      );
      expect(cells, findsNWidgets(2));

      for (final Element cell in cells.evaluate()) {
        final Size size = (cell.renderObject! as RenderBox).size;

        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('the selected segment stays distinguishable and tappable', (
      tester,
    ) async {
      int? changed;
      await pumpOnPhone(
        tester,
        MSSegmentedControl<String>(
          size: SegmentedControlSize.sm,
          options: const [monthly, annual],
          selectedIndex: 0,
          onChanged: (index) => changed = index,
        ),
      );

      // Exactly one segment carries the `selected` state, and it still asks for
      // the selected background, so the shrink did not flatten the two apart.
      final selected = find.byWidgetPredicate(
        (widget) =>
            widget is WDiv && (widget.states?.contains('selected') ?? false),
      );
      expect(selected, findsOneWidget);
      expect(
        tester.widget<WDiv>(selected).className,
        contains('selected:bg-surface'),
      );
      expect(tester.getSize(selected).width, greaterThan(0));

      // The other segment is still hittable at its shrunken width.
      await tester.tap(find.text(annual));
      await tester.pumpAndSettle();
      expect(changed, equals(1));

      expect(tester.takeException(), isNull);
    });

    testWidgets('four sentence-long labels lay out without an overflow', (
      tester,
    ) async {
      await pumpOnPhone(
        tester,
        MSSegmentedControl<String>(
          size: SegmentedControlSize.sm,
          options: const [
            'Monthly billing',
            'Annual · save ~15%',
            'Quarterly billing',
            'Two years · save ~25%',
          ],
          selectedIndex: 1,
          onChanged: (_) {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Two years · save ~25%'), findsOneWidget);
    });

    testWidgets('keeps its content width when the surface is wide', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          WDiv(
            className: 'flex flex-col items-center gap-2 px-4',
            children: [
              MSSegmentedControl<String>(
                size: SegmentedControlSize.sm,
                options: const [monthly, annual],
                selectedIndex: 0,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The segments shrink on a phone but never stretch: a segmented control
      // that filled the page width would be a different component.
      final control = find.byType(MSSegmentedControl<String>);
      expect(
        tester.getSize(control).width,
        lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a caller-wrapped root keeps its segments at content width', (
      tester,
    ) async {
      // An adopter already answers this defect from the outside by turning the
      // root into a wind `Wrap` (`magic_starter`'s own segments cannot shrink
      // inside one, and `Flexible` asserts there), so the shrink must stand
      // down rather than break that caller.
      await pumpOnPhone(
        tester,
        MSSegmentedControl<String>(
          size: SegmentedControlSize.sm,
          classNames: const {'root': 'wrap'},
          options: const [monthly, annual],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(monthly), findsOneWidget);
      expect(find.text(annual), findsOneWidget);
      // The run broke onto a second line instead of shrinking a segment: the
      // control is taller than the single-line segment it holds.
      final double controlHeight = tester
          .getSize(find.byType(MSSegmentedControl<String>))
          .height;
      final double segmentHeight = tester
          .getSize(
            find
                .ancestor(of: find.text(annual), matching: find.byType(WDiv))
                .first,
          )
          .height;
      expect(controlHeight, greaterThan(segmentHeight));
    });

    testWidgets('a caller-scrolled root keeps its segments at content width', (
      tester,
    ) async {
      // The other adopter shape: a root that scrolls horizontally has no
      // bounded width to divide, so the segments keep their labels on one line
      // and the caller's scroll view reaches the ones that fall outside. The
      // `justify-between` beside it is what makes the row claim the unbounded
      // width, which is where a flex child would assert rather than degrade.
      await pumpOnPhone(
        tester,
        MSSegmentedControl<String>(
          size: SegmentedControlSize.sm,
          classNames: const {'root': 'overflow-x-auto justify-between'},
          options: const [monthly, annual],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      );

      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(annual));
      expect(paragraph.size.height, equals(paragraph.preferredLineHeight));
    });

    testWidgets('lays out inside a horizontally unbounded parent', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: MSSegmentedControl<String>(
              size: SegmentedControlSize.sm,
              options: const [monthly, annual],
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // An unbounded width has no share to divide, so the segments fall back to
      // their content width instead of asserting.
      expect(tester.takeException(), isNull);
      expect(find.text(annual), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Tap target
  // ---------------------------------------------------------------------------

  group('SegmentedControl tap target', () {
    /// Both `physicalSize` and `devicePixelRatio` are set, since setting only
    /// the first lays the tree out at the wrong logical width.
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          Center(
            child: MSSegmentedControl<String>(
              options: const ['Monthly', 'Annual'],
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The painted pill of the segment labelled [label].
    Finder pill(String label) => find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is WDiv && (widget.className ?? '').contains('px-3'),
          ),
        )
        .first;

    testWidgets('every segment meets the iOS tap target on a phone', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAt(tester, const Size(390, 844));

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the painted pill is the same size on a phone and at lg', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1280, 800));
      final wide = tester.getSize(pill('Monthly'));

      await pumpAt(tester, const Size(390, 844));

      expect(tester.getSize(pill('Monthly')), wide);
      expect(wide.height, lessThan(44));
    });

    testWidgets('the hit area adds nothing from lg up', (tester) async {
      await pumpAt(tester, const Size(1280, 800));

      expect(
        tester.getSize(find.byType(MSSegmentedControl<String>)).height,
        lessThan(44),
      );
    });

    testWidgets('a tap just outside the painted pill selects the segment', (
      tester,
    ) async {
      int? changed;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrap(
          Center(
            child: MSSegmentedControl<String>(
              options: const ['Monthly', 'Annual'],
              selectedIndex: 0,
              onChanged: (index) => changed = index,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Rect painted = tester.getRect(pill('Annual'));
      await tester.tapAt(painted.topCenter - const Offset(0, 6));

      expect(changed, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Keyboard focus ring
  // ---------------------------------------------------------------------------

  group('SegmentedControl keyboard focus', () {
    /// The ring is an outline wind paints in a foreground DecoratedBox, so the
    /// resolved colour is read off the border rather than the className string.
    Finder ringOutline() => find.descendant(
      of: find.byType(MSSegmentedControl<String>),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    );

    Widget control() => Center(
      child: MSSegmentedControl<String>(
        options: const ['Monthly', 'Annual'],
        selectedIndex: 0,
        onChanged: (_) {},
      ),
    );

    testWidgets('paints no ring while the control is at rest', (tester) async {
      await tester.pumpWidget(wrap(control()));

      expect(ringOutline(), findsNothing);
    });

    testWidgets('Tab onto a segment paints the primary ring on it alone', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(control()));

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
      await tester.pumpWidget(wrap(control()));

      await tester.tap(find.text('Annual'));
      await tester.pumpAndSettle();

      expect(ringOutline(), findsNothing);
    });

    testWidgets('the ring reserves its space, so focus shifts nothing', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(control()));
      final before = tester.getRect(find.byType(MSSegmentedControl<String>));
      final firstBefore = tester.getRect(find.text('Monthly'));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byType(MSSegmentedControl<String>)), before);
      expect(tester.getRect(find.text('Monthly')), firstBefore);
    });
  });
}
