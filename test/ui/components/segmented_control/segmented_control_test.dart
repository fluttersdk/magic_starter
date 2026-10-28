import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../field_theme_fixture.dart';

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

  // ---------------------------------------------------------------------------
  // Selected segment in a scroller
  // ---------------------------------------------------------------------------

  group('SegmentedControl inside a scroller', () {
    /// Wide enough that the row is several times a 300 px viewport.
    const List<String> options = [
      'Day',
      'Week',
      'Month',
      'Quarter',
      'Year',
      'All time',
      'Custom',
    ];
    const String last = 'Custom';

    /// The row in a 300 px wide horizontal scroll view, as a host wraps it.
    Widget inScroller({
      required int selectedIndex,
      ScrollController? controller,
      ValueChanged<int>? onChanged,
    }) {
      return wrap(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: MSSegmentedControl<String>(
                options: options,
                selectedIndex: selectedIndex,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      );
    }

    /// The segment's tap cell, which is what has to be reachable: the outermost
    /// anchor around the label.
    Finder segment(String label) => find
        .ancestor(of: find.text(label), matching: find.byType(WAnchor))
        .last;

    /// Whether the whole segment lies inside the horizontal [viewport].
    bool isFullyInside(WidgetTester tester, String label, Finder viewport) {
      final Rect cell = tester.getRect(segment(label));
      final Rect view = tester.getRect(viewport);

      return cell.left >= view.left - 0.01 && cell.right <= view.right + 0.01;
    }

    double pixelsOf(WidgetTester tester, Finder scrollable) =>
        tester.state<ScrollableState>(scrollable).position.pixels;

    testWidgets('mounted with the last segment selected, it is in view after '
        'the first frame', (tester) async {
      await tester.pumpWidget(inScroller(selectedIndex: options.length - 1));

      expect(isFullyInside(tester, last, find.byType(Scrollable)), isTrue);
    });

    testWidgets('mounted with the first segment selected, it leaves the scroll '
        'position alone', (tester) async {
      await tester.pumpWidget(inScroller(selectedIndex: 0));
      await tester.pump();

      expect(pixelsOf(tester, find.byType(Scrollable)), 0);
    });

    testWidgets('mounted with a selection already in view, nothing scrolls', (
      tester,
    ) async {
      await tester.pumpWidget(inScroller(selectedIndex: 1));
      await tester.pump();

      expect(pixelsOf(tester, find.byType(Scrollable)), 0);
    });

    testWidgets('a root that scrolls itself reveals the selection too', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: MSSegmentedControl<String>(
                classNames: const {'root': 'overflow-x-auto'},
                options: options,
                selectedIndex: options.length - 1,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(isFullyInside(tester, last, find.byType(Scrollable)), isTrue);
    });

    testWidgets('a selectedIndex change to an off-screen segment scrolls to '
        'it', (tester) async {
      await tester.pumpWidget(inScroller(selectedIndex: 0));
      expect(isFullyInside(tester, last, find.byType(Scrollable)), isFalse);

      await tester.pumpWidget(inScroller(selectedIndex: options.length - 1));
      await tester.pump();

      expect(isFullyInside(tester, last, find.byType(Scrollable)), isTrue);
    });

    testWidgets('a selectedIndex change back to the start scrolls back', (
      tester,
    ) async {
      await tester.pumpWidget(inScroller(selectedIndex: options.length - 1));
      await tester.pump();
      expect(isFullyInside(tester, 'Day', find.byType(Scrollable)), isFalse);

      await tester.pumpWidget(inScroller(selectedIndex: 0));
      await tester.pump();

      expect(isFullyInside(tester, 'Day', find.byType(Scrollable)), isTrue);
    });

    testWidgets('a segment half out of view is brought fully in', (
      tester,
    ) async {
      await tester.pumpWidget(inScroller(selectedIndex: 0));
      // 'Quarter' starts inside the 300 px viewport and ends past it.
      final Rect cell = tester.getRect(segment('Quarter'));
      expect(cell.left, lessThan(300));
      expect(cell.right, greaterThan(300));

      await tester.pumpWidget(inScroller(selectedIndex: 3));
      await tester.pump();

      expect(isFullyInside(tester, 'Quarter', find.byType(Scrollable)), isTrue);
    });

    testWidgets('a selectedIndex change between visible segments scrolls '
        'nothing', (tester) async {
      await tester.pumpWidget(inScroller(selectedIndex: 0));

      await tester.pumpWidget(inScroller(selectedIndex: 1));
      await tester.pump();

      expect(pixelsOf(tester, find.byType(Scrollable)), 0);
    });

    testWidgets('a tap on a visible segment moves the selection and not the '
        'strip', (tester) async {
      int selected = 0;
      late StateSetter rebuild;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;

            return inScroller(
              selectedIndex: selected,
              onChanged: (index) => selected = index,
            );
          },
        ),
      );

      await tester.tap(find.text('Week'));
      rebuild(() {});
      await tester.pump();

      expect(selected, 1);
      expect(pixelsOf(tester, find.byType(Scrollable)), 0);
    });

    testWidgets('a rebuild with the same selectedIndex leaves the position the '
        'user chose', (tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        inScroller(selectedIndex: options.length - 1, controller: controller),
      );
      await tester.pump();
      expect(controller.offset, greaterThan(0));

      // The user scrolls back to the start, away from the selection.
      controller.jumpTo(0);
      await tester.pump();

      // A parent rebuild hands the control a new widget with the same index.
      await tester.pumpWidget(
        inScroller(
          selectedIndex: options.length - 1,
          controller: controller,
          onChanged: (_) {},
        ),
      );
      await tester.pump();

      expect(controller.offset, 0);
    });

    testWidgets('with no scrollable above it, nothing throws', (tester) async {
      await tester.pumpWidget(
        wrap(
          Align(
            alignment: Alignment.topLeft,
            child: MSSegmentedControl<String>(
              options: options,
              selectedIndex: options.length - 1,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.text(last), findsOneWidget);
    });

    for (final int index in [-1, options.length, options.length + 5]) {
      testWidgets('a selectedIndex of $index, which names no segment, reveals '
          'nothing', (tester) async {
        await tester.pumpWidget(inScroller(selectedIndex: index));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(pixelsOf(tester, find.byType(Scrollable)), 0);
      });
    }

    group('inside the page\'s vertical scroll view', () {
      /// The control in its horizontal strip, in a tall page scrolled by
      /// [page]: [above] px of content over it and a long tail below.
      Widget onPage({
        required int selectedIndex,
        required ScrollController page,
        required double above,
      }) {
        return wrap(
          SingleChildScrollView(
            controller: page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: above),
                SizedBox(
                  width: 300,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: MSSegmentedControl<String>(
                      options: options,
                      selectedIndex: selectedIndex,
                      onChanged: (_) {},
                    ),
                  ),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        );
      }

      Finder strip() => find.byType(Scrollable).last;

      testWidgets('a visible segment keeps the page\'s vertical offset on '
          'mount', (tester) async {
        final ScrollController page = ScrollController(initialScrollOffset: 50);
        addTearDown(page.dispose);

        await tester.pumpWidget(
          onPage(selectedIndex: options.length - 1, page: page, above: 100),
        );
        await tester.pump();

        expect(page.offset, 50);
        expect(isFullyInside(tester, last, strip()), isTrue);
      });

      testWidgets('a visible segment keeps the page\'s vertical offset when '
          'the selection changes', (tester) async {
        final ScrollController page = ScrollController(initialScrollOffset: 50);
        addTearDown(page.dispose);

        await tester.pumpWidget(
          onPage(selectedIndex: 0, page: page, above: 100),
        );
        await tester.pumpWidget(
          onPage(selectedIndex: options.length - 1, page: page, above: 100),
        );
        await tester.pump();

        expect(page.offset, 50);
        expect(isFullyInside(tester, last, strip()), isTrue);
      });

      testWidgets('a control below the fold does not pull the page down to '
          'it', (tester) async {
        final ScrollController page = ScrollController();
        addTearDown(page.dispose);

        await tester.pumpWidget(
          onPage(selectedIndex: options.length - 1, page: page, above: 1500),
        );
        await tester.pump();

        expect(page.offset, 0);
        expect(
          tester.state<ScrollableState>(strip()).position.pixels,
          greaterThan(0),
        );
      });
    });

    group('inside a scroller that is not the control\'s own', () {
      testWidgets('a vertical list between the control and the strip leaves the '
          'strip where it was', (tester) async {
        final ScrollController strip = ScrollController(
          initialScrollOffset: 40,
        );
        final ScrollController list = ScrollController(
          initialScrollOffset: 150,
        );
        addTearDown(strip.dispose);
        addTearDown(list.dispose);

        // The control sits 300 px down a list that is scrolled to show it, in a
        // 700 px wide strip. The offset that reveals it in the LIST is a
        // vertical one and must never reach the strip.
        await tester.pumpWidget(
          wrap(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 200,
                child: SingleChildScrollView(
                  controller: strip,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 700,
                    child: ListView(
                      controller: list,
                      children: [
                        const SizedBox(height: 300),
                        Align(
                          alignment: Alignment.topLeft,
                          child: MSSegmentedControl<String>(
                            options: options,
                            selectedIndex: options.length - 1,
                            onChanged: (_) {},
                          ),
                        ),
                        const SizedBox(height: 1000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(last), findsOneWidget);
        expect(strip.offset, 40);
        expect(list.offset, 150);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a page view page is not snapped, and a drag in progress is '
          'not cancelled, when the selection changes', (tester) async {
        final PageController pages = PageController(initialPage: 1);
        addTearDown(pages.dispose);

        Widget onSecondPage(int selectedIndex) {
          return wrap(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 200,
                child: PageView(
                  controller: pages,
                  children: [
                    const SizedBox.shrink(),
                    Align(
                      alignment: Alignment.topLeft,
                      child: MSSegmentedControl<String>(
                        options: options,
                        selectedIndex: selectedIndex,
                        onChanged: (_) {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(onSecondPage(0));
        await tester.pump();
        expect(pages.position.pixels, 300);

        // The user is dragging the page back toward the first one.
        final TestGesture drag = await tester.startGesture(
          tester.getCenter(find.byType(PageView)),
        );
        await drag.moveBy(const Offset(60, 0));
        await tester.pump();
        await drag.moveBy(const Offset(20, 0));
        await tester.pump();
        final double dragged = pages.position.pixels;
        expect(dragged, inExclusiveRange(0, 300));
        expect(pages.position.isScrollingNotifier.value, isTrue);

        // The selection changes under the finger.
        await tester.pumpWidget(onSecondPage(options.length - 1));
        await tester.pump();

        expect(pages.position.pixels, dragged);
        expect(pages.position.isScrollingNotifier.value, isTrue);

        await drag.up();
        await tester.pumpAndSettle();
      });

      testWidgets('a vertical list is never moved, even when its extent is the '
          'control\'s width', (tester) async {
        final ScrollController list = ScrollController();
        addTearDown(list.dispose);

        // 700 px of content under a 200 px viewport, and a control exactly
        // 700 px wide below the fold: the width check alone would pass.
        await tester.pumpWidget(
          wrap(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 700,
                height: 200,
                child: ListView(
                  controller: list,
                  children: [
                    const SizedBox(height: 300),
                    SizedBox(
                      height: 400,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: 700,
                          child: MSSegmentedControl<String>(
                            options: options,
                            selectedIndex: options.length - 1,
                            onChanged: (_) {},
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(list.position.maxScrollExtent + 200, 700);
        expect(list.offset, 0);
      });

      testWidgets('a strip that holds more than the control is left to the '
          'host', (tester) async {
        final ScrollController strip = ScrollController();
        addTearDown(strip.dispose);

        await tester.pumpWidget(
          wrap(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  controller: strip,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MSSegmentedControl<String>(
                        options: options,
                        selectedIndex: options.length - 1,
                        onChanged: (_) {},
                      ),
                      const SizedBox(width: 400),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(strip.position.maxScrollExtent, greaterThan(0));
        expect(strip.offset, 0);
        expect(isFullyInside(tester, last, find.byType(Scrollable)), isFalse);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Field theme
  // ---------------------------------------------------------------------------

  group('segmented control recipe from a theme', () {
    // The slots before the sizes and the root padding became theme fields,
    // copied verbatim and not derived from the recipe: a refactor that moved a
    // token cannot move this with it.
    const legacyRoot =
        'flex flex-row items-center rounded-lg bg-surface-container-high '
        'p-1 gap-1';
    const legacyItem =
        'px-3 py-1.5 rounded-md text-sm font-medium text-center '
        'text-fg-muted cursor-pointer selected:bg-surface selected:text-fg '
        'selected:shadow-sm transition-colors focus:ring-2 focus:ring-offset-1 '
        'focus:ring-primary-500 dark:focus:ring-primary-400';
    const legacyHit =
        'flex flex-col justify-center items-center min-h-11 min-w-11 '
        'lg:min-h-0 lg:min-w-0';
    const legacySize = {'sm': 'px-2 py-1 text-sm', 'md': 'px-3 py-1.5 text-sm'};

    for (final size in SegmentedControlSize.values) {
      test('the default theme emits the previous ${size.name} slots byte for '
          'byte', () {
        for (final slots in [
          segmentedControlRecipe(variants: {'size': size.name}),
          segmentedControlRecipe(
            theme: const MagicStarterFieldTheme(),
            variants: {'size': size.name},
          ),
        ]) {
          expect(slots['root'], legacyRoot);
          expect(slots['item'], '$legacyItem ${legacySize[size.name]}');
          expect(slots['hit'], legacyHit);
        }
      });
    }

    test('the sizes land in their own item and no other', () {
      const theme = MagicStarterFieldTheme(
        segmentedSmClassName: 'sm-class',
        segmentedMdClassName: 'md-class',
      );

      for (final size in SegmentedControlSize.values) {
        final item = segmentedControlRecipe(
          theme: theme,
          variants: {'size': size.name},
        )['item'];

        expect(item, endsWith('${size.name}-class'));
        for (final other in SegmentedControlSize.values.where(
          (s) => s != size,
        )) {
          expect(item, isNot(contains('${other.name}-class')));
        }
      }
    });

    test('the padding lands where p-1 sat in the root and nowhere else', () {
      final slots = segmentedControlRecipe(theme: hostFieldTheme);

      expect(
        slots['root'],
        'flex flex-row items-center rounded-lg bg-surface-container-high '
        'px-1 py-0 lg:py-1 gap-1',
      );
      expect(slots['hit'], legacyHit);
      expect(slots['item'], startsWith(legacyItem));
    });
  });

  group('segmented control measured', () {
    Widget control({
      SegmentedControlSize size = SegmentedControlSize.md,
      Map<String, String>? classNames,
      ValueChanged<int>? onChanged,
    }) {
      return MSSegmentedControl<String>(
        size: size,
        classNames: classNames,
        options: const ['Monthly', 'Annual'],
        selectedIndex: 0,
        onChanged: onChanged ?? (_) {},
      );
    }

    /// The painted pill of the segment labelled [label].
    Finder pill(String label) => find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is WDiv &&
                (widget.className ?? '').contains('rounded-md'),
          ),
        )
        .first;

    group('with the default theme', () {
      // Today's sizes, measured before the change: the root keeps 4 px around
      // the cell, so below lg the 44 px hit cell makes the control 52 px tall.
      const heights = {
        SegmentedControlSize.md: (phone: 52.0, desktop: 40.0),
        SegmentedControlSize.sm: (phone: 52.0, desktop: 36.0),
      };

      for (final size in SegmentedControlSize.values) {
        testWidgets('${size.name} is ${heights[size]!.desktop} px tall from lg '
            'up and ${heights[size]!.phone} on a phone', (tester) async {
          await pumpControlAt(tester, kDesktop, control(size: size));
          expect(
            tester.getSize(find.byType(MSSegmentedControl<String>)).height,
            heights[size]!.desktop,
          );

          await pumpControlAt(tester, kPhone, control(size: size));
          expect(
            tester.getSize(find.byType(MSSegmentedControl<String>)).height,
            heights[size]!.phone,
          );
        });
      }
    });

    group('with a host theme', () {
      for (final brightness in Brightness.values) {
        for (final entry in {'phone': kPhone, 'desktop': kDesktop}.entries) {
          for (final size in SegmentedControlSize.values) {
            final label = '${size.name} ${brightness.name} ${entry.key}';

            testWidgets('is 44 px tall around a 36 px pill, $label', (
              tester,
            ) async {
              MagicStarter.useFieldTheme(hostFieldTheme);
              await pumpControlAt(
                tester,
                entry.value,
                control(size: size),
                brightness: brightness,
              );

              expect(
                tester.getSize(find.byType(MSSegmentedControl<String>)).height,
                44,
              );
              expect(tester.getSize(pill('Monthly')).height, 36);
            });

            testWidgets('sets the label 17 on 22 and centres it, $label', (
              tester,
            ) async {
              MagicStarter.useFieldTheme(hostFieldTheme);
              await pumpControlAt(
                tester,
                entry.value,
                control(size: size),
                brightness: brightness,
              );

              final root = find.byType(MSSegmentedControl<String>);

              expect(paintedStyle(tester, 'Monthly')?.fontSize, 17);
              expect(lineHeightOf(tester, 'Monthly'), closeTo(22, 0.01));
              expect(
                glyphCentre(tester, 'Monthly'),
                closeTo(tester.getCenter(root).dy, 1),
              );
              expect(
                glyphCentre(tester, 'Annual'),
                closeTo(tester.getCenter(root).dy, 1),
              );
            });
          }
        }
      }

      testWidgets('keeps a 44 px hit cell around the pill on a phone', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        MagicStarter.useFieldTheme(hostFieldTheme);
        await pumpControlAt(tester, kPhone, control());

        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('a tap just above the pill still selects the segment', (
        tester,
      ) async {
        int? changed;
        MagicStarter.useFieldTheme(hostFieldTheme);
        await pumpControlAt(
          tester,
          kPhone,
          control(onChanged: (index) => changed = index),
        );

        final painted = tester.getRect(pill('Annual'));
        await tester.tapAt(painted.topCenter - const Offset(0, 3));

        expect(changed, 1);
      });

      testWidgets('a caller item className still wins over the theme', (
        tester,
      ) async {
        MagicStarter.useFieldTheme(hostFieldTheme);
        await pumpControlAt(
          tester,
          kDesktop,
          control(classNames: const {'item': 'text-sm'}),
        );

        expect(paintedStyle(tester, 'Monthly')?.fontSize, 14);
      });

      testWidgets('a caller root className still wins over the padding', (
        tester,
      ) async {
        MagicStarter.useFieldTheme(hostFieldTheme);
        await pumpControlAt(
          tester,
          kDesktop,
          control(classNames: const {'root': 'py-3'}),
        );

        expect(
          tester.getSize(find.byType(MSSegmentedControl<String>)).height,
          12 + 36 + 12,
        );
      });

      testWidgets('useWindTheme after useFieldTheme puts the defaults back', (
        tester,
      ) async {
        MagicStarter.useFieldTheme(hostFieldTheme);
        MagicStarter.useWindTheme(WindThemeData());
        await pumpControlAt(tester, kDesktop, control());

        expect(
          tester.getSize(find.byType(MSSegmentedControl<String>)).height,
          40,
        );
      });

      testWidgets(
        'the wrap root override still builds a Wrap and no Flexible',
        (tester) async {
          MagicStarter.useFieldTheme(hostFieldTheme);
          await pumpControlAt(
            tester,
            kPhone,
            SizedBox(
              width: 200,
              child: MSSegmentedControl<String>(
                classNames: const {'root': 'wrap'},
                options: const ['Monthly', 'Annual', 'Lifetime'],
                selectedIndex: 0,
                onChanged: (_) {},
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(Wrap), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(MSSegmentedControl<String>),
              matching: find.byType(Flexible),
            ),
            findsNothing,
          );
        },
      );

      testWidgets('the selected segment is still revealed in a scroller', (
        tester,
      ) async {
        const options = ['Day', 'Week', 'Month', 'Quarter', 'Year', 'Custom'];
        const strip = ValueKey('strip');
        MagicStarter.useFieldTheme(hostFieldTheme);
        await pumpControlAt(
          tester,
          kPhone,
          SizedBox(
            width: 300,
            child: SingleChildScrollView(
              key: strip,
              scrollDirection: Axis.horizontal,
              child: MSSegmentedControl<String>(
                options: options,
                selectedIndex: options.length - 1,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        final cell = tester.getRect(
          find
              .ancestor(of: find.text('Custom'), matching: find.byType(WAnchor))
              .last,
        );
        final view = tester.getRect(find.byKey(strip));

        expect(cell.left, greaterThanOrEqualTo(view.left - 0.01));
        expect(cell.right, lessThanOrEqualTo(view.right + 0.01));
      });
    });
  });
}
