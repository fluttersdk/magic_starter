import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/page_header/page_header.dart'
    show MSPageHeaderHeadingScope;
import 'package:magic_starter/src/ui/components/page_header/page_header.preview.dart';

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
  // Behavior gate: these assertions came from the pre-MS-prefix alias test.
  // ---------------------------------------------------------------------------

  testWidgets('renders required title', (tester) async {
    await tester.pumpWidget(wrap(const MSPageHeader(title: 'My Page')));
    expect(find.text('My Page'), findsOneWidget);
  });

  testWidgets('renders subtitle when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSPageHeader(title: 'Projects', subtitle: 'Manage your projects'),
      ),
    );
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Manage your projects'), findsOneWidget);
  });

  testWidgets('does not render subtitle when omitted', (tester) async {
    await tester.pumpWidget(wrap(const MSPageHeader(title: 'Projects')));
    final texts = tester.widgetList<WText>(find.byType(WText)).toList();
    expect(texts.length, 1);
    expect(texts.first.data, 'Projects');
  });

  testWidgets('renders leading widget when provided', (tester) async {
    const leadingKey = Key('back-btn');
    await tester.pumpWidget(
      wrap(
        const MSPageHeader(
          title: 'Detail',
          leading: Icon(Icons.arrow_back, key: leadingKey),
        ),
      ),
    );
    expect(find.byKey(leadingKey), findsOneWidget);
  });

  testWidgets('renders actions list when provided', (tester) async {
    const actionKey = Key('action-btn');
    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'Projects',
          actions: [
            ElevatedButton(
              key: actionKey,
              onPressed: () {},
              child: const Text('New'),
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(actionKey), findsOneWidget);
  });

  testWidgets('outer WDiv has responsive sm:flex-row class', (tester) async {
    await tester.pumpWidget(wrap(const MSPageHeader(title: 'Responsive')));
    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('sm:flex-row'));
  });

  testWidgets('titleSuffix renders inline after title when provided', (
    tester,
  ) async {
    const suffixKey = Key('test_suffix');
    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'My Page',
          titleSuffix: Container(key: suffixKey),
        ),
      ),
    );
    expect(find.byKey(suffixKey), findsOneWidget);
  });

  testWidgets(
    'inlineActions keeps the title readable beside a leading and a suffix',
    (tester) async {
      // The className assertion below cannot see this: with a leading control,
      // a long title and a titleSuffix, the inline row collapsed the title to a
      // couple of glyphs on a phone while leaving most of the row EMPTY.
      // Measured on an iPhone at 402pt: the title occupied about 10pt and
      // everything past the suffix was blank, because `justify-between` handed
      // the icon-sized actions column an EQUAL flex share and it reserved half
      // the header.
      //
      // Asserted on the two wrappers, not on the text: a widget test lays text
      // out in a placeholder font roughly one em per glyph, so any assertion
      // that compares a title against a badge measures the harness. An icon
      // column's width and a row's share of the header are layout.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(402, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          MSPageHeader(
            title: 'iOS Sweep Monitor',
            subtitle: 'https://example.com',
            inlineActions: true,
            leading: const Icon(Icons.chevron_left),
            titleSuffix: const Text('Operational'),
            actions: [const Icon(Icons.more_horiz)],
          ),
        ),
      );
      await tester.pump();

      final double actionsWidth = tester
          .getSize(
            find
                .ancestor(
                  of: find.byIcon(Icons.more_horiz),
                  matching: find.byType(WDiv),
                )
                .first,
          )
          .width;
      final double titleRowWidth = tester
          .getSize(
            find
                .byWidgetPredicate(
                  (w) => w is WDiv && (w.className ?? '').contains('flex-1'),
                )
                .first,
          )
          .width;

      expect(
        actionsWidth,
        lessThan(64),
        reason:
            'a single icon action is icon-sized; it cannot reserve a share '
            'of the header it never paints',
      );
      expect(
        titleRowWidth,
        greaterThan(300),
        reason:
            'the title row is the page identity and takes what the actions '
            'do not need, so on a 402pt phone it spans nearly the whole header',
      );
    },
  );

  testWidgets('inlineActions: true outer WDiv className contains flex-row', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'Inline',
          inlineActions: true,
          actions: [ElevatedButton(onPressed: () {}, child: const Text('Go'))],
        ),
      ),
    );
    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('flex-row'));
    expect(outerDiv.className, isNot(contains('flex-col')));
  });

  testWidgets('inlineActions: false (default) retains flex-col sm:flex-row', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'Default Layout',
          actions: [ElevatedButton(onPressed: () {}, child: const Text('Go'))],
        ),
      ),
    );
    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('flex-col'));
    expect(outerDiv.className, contains('sm:flex-row'));
  });

  testWidgets('the theme can turn every header inline without an argument', (
    tester,
  ) async {
    // An app that themes the container into a row at every width has to be able
    // to say so once. `MSPageScaffold` does not expose `inlineActions`, so
    // before this the theme was the only half of the decision a scaffold
    // consumer could set, and setting it alone is what overflows.
    MagicStarter.usePageHeaderTheme(
      const MagicStarterPageHeaderTheme(inlineActions: true),
    );

    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'Themed inline',
          actions: [ElevatedButton(onPressed: () {}, child: const Text('Go'))],
        ),
      ),
    );

    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('flex-row'));
    expect(outerDiv.className, isNot(contains('flex-col')));
  });

  testWidgets('inline mode gives the title row flex-1 so a long title shrinks', (
    tester,
  ) async {
    // **The half that was missing, and the one that actually overflows.**
    // `inlineActions` swaps the container class AND claims the remaining width
    // for the title row. The title column is `flex-initial`, a loose fit, so
    // without `flex-1` on the row the text takes its intrinsic width and runs
    // past the actions: measured at 40 logical pixels on a 390px viewport.
    MagicStarter.usePageHeaderTheme(
      const MagicStarterPageHeaderTheme(inlineActions: true),
    );

    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'A title long enough to need the whole row to itself',
          actions: [ElevatedButton(onPressed: () {}, child: const Text('Go'))],
        ),
      ),
    );

    final titleRow = tester.widgetList<WDiv>(find.byType(WDiv)).elementAt(1);

    expect(titleRow.className, contains('flex-1'));
    expect(titleRow.className, isNot(contains('sm:flex-1')));
    expect(titleRow.className, contains('min-w-0'));
  });

  testWidgets('an explicit argument still beats the theme', (tester) async {
    // The theme is a default rather than a lock: a single screen that wants the
    // stacked layout can still ask for it.
    MagicStarter.usePageHeaderTheme(
      const MagicStarterPageHeaderTheme(inlineActions: true),
    );

    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'Explicitly stacked',
          inlineActions: false,
          actions: [ElevatedButton(onPressed: () {}, child: const Text('Go'))],
        ),
      ),
    );

    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('flex-col'));
  });

  testWidgets('a header does not overflow at phone width when themed inline', (
    tester,
  ) async {
    // **The defect itself, as a test.** Depools themed the container into a row
    // at every width so a phone header keeps its action beside the title, and
    // the product screen then reported `A RenderFlex overflowed by 40 pixels`
    // at 390. Nothing in the app's own code was in that row.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    MagicStarter.usePageHeaderTheme(
      const MagicStarterPageHeaderTheme(inlineActions: true),
    );

    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'Dishwasher Tablets',
          actions: [
            for (int i = 0; i < 3; i++)
              const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.more_horiz),
              ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // className
  // ---------------------------------------------------------------------------

  // A pushed screen puts its own bar above the scaffold, so the header's own
  // top padding stacks on the bar's height. The header takes a className for
  // its container, appended after the theme's like MSPageContainer.className.
  group('className', () {
    const phone = Size(390, 844);
    const desktop = Size(1440, 900);

    Future<void> pumpAt(WidgetTester tester, Size size, Widget header) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(Align(alignment: Alignment.topLeft, child: header)),
      );
      await tester.pump();
    }

    double titleTop(WidgetTester tester) =>
        tester.getTopLeft(find.text('Settings')).dy;

    testWidgets(
      'a header without one keeps the theme container byte for byte',
      (tester) async {
        await tester.pumpWidget(wrap(const MSPageHeader(title: 'Settings')));

        expect(
          tester.widget<WDiv>(find.byType(WDiv).first).className,
          const MagicStarterPageHeaderTheme().containerClassName,
        );
      },
    );

    testWidgets('an empty className adds nothing to the theme container', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MSPageHeader(title: 'Settings', className: '')),
      );

      expect(
        tester.widget<WDiv>(find.byType(WDiv).first).className,
        const MagicStarterPageHeaderTheme().containerClassName,
      );
    });

    testWidgets('is appended after the theme container class', (tester) async {
      await tester.pumpWidget(
        wrap(const MSPageHeader(title: 'Settings', className: 'pt-0')),
      );

      expect(
        tester.widget<WDiv>(find.byType(WDiv).first).className,
        '${const MagicStarterPageHeaderTheme().containerClassName} pt-0',
      );
    });

    testWidgets('is appended after the inline container class too', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const MSPageHeader(
            title: 'Settings',
            inlineActions: true,
            className: 'pt-0',
          ),
        ),
      );

      expect(
        tester.widget<WDiv>(find.byType(WDiv).first).className,
        '${const MagicStarterPageHeaderTheme().containerInlineClassName} pt-0',
      );
    });

    testWidgets('pt-0 takes the top padding off and keeps the other sides', (
      tester,
    ) async {
      await pumpAt(tester, phone, const MSPageHeader(title: 'Settings'));
      final double padded = titleTop(tester);
      final double bottom = tester.getBottomLeft(find.byType(MSPageHeader)).dy;

      await pumpAt(
        tester,
        phone,
        const MSPageHeader(title: 'Settings', className: 'pt-0'),
      );

      expect(padded, 8, reason: 'the theme container is p-2 below lg');
      expect(titleTop(tester), 0);
      expect(
        tester.getBottomLeft(find.byType(MSPageHeader)).dy,
        bottom - 8,
        reason: 'only the top padding went',
      );
      expect(tester.getTopLeft(find.text('Settings')).dx, 8);
    });

    testWidgets('lg:pt-0 leaves a phone header alone and clears it from lg', (
      tester,
    ) async {
      const header = MSPageHeader(title: 'Settings', className: 'lg:pt-0');

      await pumpAt(tester, phone, header);
      expect(titleTop(tester), 8);

      await pumpAt(tester, desktop, header);
      expect(titleTop(tester), 0, reason: 'lg:p-4 loses its top to lg:pt-0');
    });

    testWidgets('applies to a large title header too', (tester) async {
      await pumpAt(
        tester,
        phone,
        const MSPageHeader(
          title: 'Settings',
          size: MSPageHeaderSize.large,
          className: 'pt-0',
        ),
      );

      expect(titleTop(tester), 0);
    });

    testWidgets('a caller className wins over a themed container', (
      tester,
    ) async {
      MagicStarter.usePageHeaderTheme(
        const MagicStarterPageHeaderTheme(
          containerClassName:
              'w-full flex flex-col sm:flex-row items-start sm:items-center '
              'sm:justify-between gap-4 py-2 lg:py-3',
        ),
      );

      await pumpAt(
        tester,
        desktop,
        const MSPageHeader(title: 'Settings', className: 'lg:pt-0'),
      );

      expect(titleTop(tester), 0);
      expect(
        tester.getBottomLeft(find.byType(MSPageHeader)).dy -
            tester.getBottomLeft(find.text('Settings')).dy,
        12,
        reason: 'lg:py-3 still pads the bottom',
      );
    });

    testWidgets('the compact bar keeps its own geometry and ignores it', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const MSPageHeader(
            title: 'Settings',
            size: MSPageHeaderSize.compact,
            className: 'pt-0 bg-red-500',
          ),
        ),
      );

      final String barClassName = tester
          .widget<WDiv>(find.byType(WDiv).first)
          .className!;

      expect(
        barClassName,
        const MagicStarterPageHeaderTheme().compactBarClassName,
      );
      expect(barClassName, isNot(contains('pt-0')));
      expect(
        tester.getSize(find.byType(SizedBox).last).height,
        MSPageHeader.compactBarHeight,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Theme consumption
  // ---------------------------------------------------------------------------

  group('theme consumption', () {
    testWidgets('custom titleClassName is used', (tester) async {
      MagicStarter.manager.pageHeaderTheme = const MagicStarterPageHeaderTheme(
        titleClassName: 'custom-header-title',
      );
      await tester.pumpWidget(wrap(const MSPageHeader(title: 'My Page')));
      final titleText = tester.widgetList<WText>(find.byType(WText)).first;
      expect(titleText.className, contains('custom-header-title'));
    });

    testWidgets('custom subtitleClassName is used', (tester) async {
      MagicStarter.manager.pageHeaderTheme = const MagicStarterPageHeaderTheme(
        subtitleClassName: 'custom-header-subtitle',
      );
      await tester.pumpWidget(
        wrap(const MSPageHeader(title: 'My Page', subtitle: 'A subtitle')),
      );
      final texts = tester.widgetList<WText>(find.byType(WText)).toList();
      expect(texts[1].className, contains('custom-header-subtitle'));
    });
  });

  testWidgets('PageHeader preview renders without error', (tester) async {
    // The catalog scrolls its previews; the variant list outgrows the 600 px
    // test window since the large and compact sizes joined it.
    await tester.pumpWidget(
      wrap(const SingleChildScrollView(child: PageHeaderPreview())),
    );
    await tester.pump();
    expect(find.byType(PageHeaderPreview), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Back affordance — TDD cases
  // ---------------------------------------------------------------------------

  testWidgets('renders icon-only back leading when backLabel is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MSPageHeader(
          title: 'Profile',
          backLabel: 'Settings',
          backFallback: '/settings',
        ),
      ),
    );
    // Icon-only: the chevron renders, the parent label text is NOT shown.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('the back control announces the parent it returns to', (
    tester,
  ) async {
    // `backLabel` was a presence flag and nothing else: its string was never
    // rendered and never announced, so every page carrying a back control
    // offered a screen reader an unnamed button. The label is the one thing
    // that says where the control goes, and the caller already passes it.
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(
        const MSPageHeader(
          title: 'Profile',
          backLabel: 'Settings',
          backFallback: '/settings',
        ),
      ),
    );

    final Iterable<SemanticsNode> named = _buttonNodes(
      tester,
    ).where((SemanticsNode n) => n.getSemanticsData().label == 'Settings');

    expect(named, hasLength(1));
    // Still icon-only on screen: the name reaches assistive technology, not the
    // layout.
    expect(find.text('Settings'), findsNothing);
    handle.dispose();
  });

  testWidgets('no back control without a backFallback to navigate to', (
    tester,
  ) async {
    // `backFallback` is the control's only destination, so gating the render on
    // `backLabel` alone produced a chevron that announced itself as a button
    // (named, after this PR) and did nothing when pressed. A control that
    // cannot act is worse than no control.
    await tester.pumpWidget(
      wrap(const MSPageHeader(title: 'Profile', backLabel: 'Settings')),
    );

    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  // The derived hover tone is a pair when the host theme defines no `text-fg`
  // alias; its dark half used to apply at rest and wash the chevron out.
  testWidgets('the back control rests on the muted tone in dark mode', (
    tester,
  ) async {
    final data = WindThemeData(
      brightness: Brightness.dark,
      syncWithSystem: false,
    );
    MagicStarter.useWindTheme(data);

    await tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: data,
          child: const Scaffold(
            body: MSPageHeader(
              title: 'Profile',
              backLabel: 'Settings',
              backFallback: '/settings',
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.chevron_left)).color,
      const Color(0xFF9CA3AF),
    );
  });

  testWidgets('no back leading when backLabel is null', (tester) async {
    await tester.pumpWidget(wrap(const MSPageHeader(title: 'Dashboard')));
    // Without backLabel the chevron must not appear.
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('tap on back leading navigates to the parent route', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MSPageHeader(
          title: 'Profile',
          backLabel: 'Settings',
          backFallback: '/settings',
        ),
      ),
    );

    // Precondition: the icon-only back control renders.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    // Act: tap the chevron. MagicRouter is not initialized in widget tests, so
    // MagicRoute.to(...) throws; the thrown exception confirms navigation was
    // actually invoked (the wrong behavior would be silence — no call).
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    expect(tester.takeException(), isNotNull);
  });

  // ---------------------------------------------------------------------------
  // Optional-slot omission — an absent slot must add no wrapper, not an empty
  // one. A wrapper that renders for a null slot still consumes a gap row, which
  // is how a self-hiding child ends up pushing its neighbours out of rhythm.
  // ---------------------------------------------------------------------------

  testWidgets('renders multiple actions', (tester) async {
    const firstKey = Key('btn-1');
    const secondKey = Key('btn-2');

    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'Settings',
          actions: [
            ElevatedButton(
              key: firstKey,
              onPressed: () {},
              child: const Text('Save'),
            ),
            ElevatedButton(
              key: secondKey,
              onPressed: () {},
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(firstKey), findsOneWidget);
    expect(find.byKey(secondKey), findsOneWidget);
  });

  testWidgets('renders no actions row when actions is null', (tester) async {
    await tester.pumpWidget(wrap(const MSPageHeader(title: 'No Actions')));

    expect(find.text('No Actions'), findsOneWidget);
  });

  testWidgets('renders no actions row when actions list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MSPageHeader(title: 'Empty Actions', actions: [])),
    );

    expect(find.text('Empty Actions'), findsOneWidget);
  });

  testWidgets('subtitleSuffix sits on the subtitle line, after the subtitle', (
    tester,
  ) async {
    const suffixKey = Key('subtitle_suffix');
    await tester.pumpWidget(
      wrap(
        const MSPageHeader(
          title: 'Shop',
          subtitle: 'https://shop.test',
          subtitleSuffix: SizedBox(key: suffixKey, width: 40, height: 12),
        ),
      ),
    );

    final Rect subtitle = tester.getRect(find.text('https://shop.test'));
    final Rect suffix = tester.getRect(find.byKey(suffixKey));

    expect(suffix.left, greaterThanOrEqualTo(subtitle.right));
    expect(suffix.center.dy, closeTo(subtitle.center.dy, 1));
  });

  testWidgets('subtitleSuffix renders nothing without a subtitle', (
    tester,
  ) async {
    const suffixKey = Key('subtitle_suffix');
    await tester.pumpWidget(
      wrap(
        const MSPageHeader(
          title: 'Shop',
          subtitleSuffix: SizedBox(key: suffixKey),
        ),
      ),
    );

    expect(find.byKey(suffixKey), findsNothing);
  });

  testWidgets('a suffix that does not fit wraps under the subtitle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    MagicStarter.usePageHeaderTheme(
      const MagicStarterPageHeaderTheme(
        inlineActions: true,
        subtitleClassName: 'text-xs truncate',
      ),
    );

    const suffixKey = Key('subtitle_suffix');
    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'Shop',
          subtitle: 'https://${'a' * 80}.test',
          subtitleSuffix: const SizedBox(key: suffixKey, width: 60, height: 12),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final Rect suffix = tester.getRect(find.byKey(suffixKey));
    expect(suffix.right, lessThanOrEqualTo(390));
    expect(
      suffix.top,
      greaterThanOrEqualTo(
        tester.getRect(find.textContaining('https://')).bottom,
      ),
    );
  });

  testWidgets('adds no suffix wrapper when titleSuffix is null', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSPageHeader(title: 'My Page')));

    final innerDivs = find.descendant(
      of: find.byType(MSPageHeader),
      matching: find.byType(WDiv),
    );

    // Outer WDiv + inner title row WDiv + title column WDiv = 3. No suffix
    // wrapper WDiv should be present.
    expect(innerDivs, findsNWidgets(3));
  });

  group('size', () {
    WText titleText(WidgetTester tester, String title) {
      return tester.widget<WText>(
        find.byWidgetPredicate((w) => w is WText && w.data == title),
      );
    }

    testWidgets('defaults to the regular title', (tester) async {
      await tester.pumpWidget(wrap(const MSPageHeader(title: 'Plain')));

      expect(
        titleText(tester, 'Plain').className,
        const MagicStarterPageHeaderTheme().titleClassName,
      );
      expect(
        tester.widget<MSPageHeader>(find.byType(MSPageHeader)).effectiveSize,
        MSPageHeaderSize.regular,
      );
    });

    testWidgets('large renders the large title class', (tester) async {
      await tester.pumpWidget(
        wrap(const MSPageHeader(title: 'Stock', size: MSPageHeaderSize.large)),
      );

      expect(
        titleText(tester, 'Stock').className,
        const MagicStarterPageHeaderTheme().largeTitleClassName,
      );
    });

    testWidgets('the shipped large title is display size, smaller from lg', (
      tester,
    ) async {
      double renderedSize() {
        final RichText text = tester.widget<RichText>(
          find.descendant(
            of: find.byType(MSPageHeader),
            matching: find.byType(RichText),
          ),
        );

        return text.text.style!.fontSize!;
      }

      final List<double> sizes = <double>[];
      for (final double width in const <double>[390, 1280]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            const MSPageHeader(title: 'Stock', size: MSPageHeaderSize.large),
          ),
        );
        sizes.add(renderedSize());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();

      expect(sizes, <double>[36, 30]);
    });

    testWidgets('the theme makes every header large without an argument', (
      tester,
    ) async {
      MagicStarter.usePageHeaderTheme(
        const MagicStarterPageHeaderTheme(
          largeTitle: true,
          largeTitleClassName: 'text-4xl font-bold',
        ),
      );

      await tester.pumpWidget(wrap(const MSPageHeader(title: 'Themed')));

      expect(titleText(tester, 'Themed').className, 'text-4xl font-bold');
    });

    testWidgets('an explicit regular size beats a large theme', (tester) async {
      MagicStarter.usePageHeaderTheme(
        const MagicStarterPageHeaderTheme(largeTitle: true),
      );

      await tester.pumpWidget(
        wrap(const MSPageHeader(title: 'Kept', size: MSPageHeaderSize.regular)),
      );

      expect(
        titleText(tester, 'Kept').className,
        const MagicStarterPageHeaderTheme().titleClassName,
      );
    });

    testWidgets('large keeps the subtitle, back control and actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MSPageHeader(
            title: 'Milk',
            subtitle: 'Dairy',
            size: MSPageHeaderSize.large,
            backLabel: 'Stock',
            backFallback: '/stock',
            actions: [
              ElevatedButton(onPressed: () {}, child: const Text('Edit')),
            ],
          ),
        ),
      );

      expect(find.text('Dairy'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('compact is a 44 pt bar with leading, title and actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Align(
            alignment: Alignment.topCenter,
            child: MSPageHeader(
              title: 'Milk',
              subtitle: 'Dairy',
              titleSuffix: const Text('suffix'),
              size: MSPageHeaderSize.compact,
              backLabel: 'Stock',
              backFallback: '/stock',
              actions: [
                ElevatedButton(onPressed: () {}, child: const Text('Edit')),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(NavigationToolbar), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      // A navigation bar has no room for the subtitle or the suffixes.
      expect(find.text('Dairy'), findsNothing);
      expect(find.text('suffix'), findsNothing);
      expect(
        tester.getSize(find.byType(NavigationToolbar)).height,
        MSPageHeader.compactBarHeight,
      );
      expect(
        titleText(tester, 'Milk').className,
        const MagicStarterPageHeaderTheme().compactTitleClassName,
      );
    });

    testWidgets('compact centres the title whatever sits beside it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          Align(
            alignment: Alignment.topCenter,
            child: MSPageHeader(
              title: 'Milk',
              size: MSPageHeaderSize.compact,
              backLabel: 'Stock',
              backFallback: '/stock',
              // A trailing side three times the chevron's width: a row would
              // push the title off centre, a navigation bar does not.
              actions: const [SizedBox(width: 120, height: 36)],
            ),
          ),
        ),
      );

      final double centre = tester.getCenter(find.text('Milk')).dx;
      expect(centre, moreOrLessEquals(195, epsilon: 1));
    });

    testWidgets('compact is glass: the translucent fill over a blur', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const Align(
            alignment: Alignment.topCenter,
            child: MSPageHeader(title: 'Glass', size: MSPageHeaderSize.compact),
          ),
        ),
      );

      final BackdropFilter filter = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(
        filter.filter.toString(),
        ImageFilter.blur(sigmaX: 20, sigmaY: 20).toString(),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is WDiv &&
              w.className ==
                  const MagicStarterPageHeaderTheme().compactBarClassName,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'the shipped bar fill resolves translucent, the opaque one not',
      (tester) async {
        // Wind drops a token it cannot parse without a word, so the fill is
        // checked as the colour it paints, not as the class string.
        Color fillOf(String title) {
          final Finder bar = find.byWidgetPredicate(
            (w) => w is MSPageHeader && w.title == title,
          );
          final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
            find.descendant(of: bar, matching: find.byType(DecoratedBox)),
          );

          return boxes
              .map((box) => box.decoration)
              .whereType<BoxDecoration>()
              .firstWhere((decoration) => decoration.color != null)
              .color!;
        }

        await tester.pumpWidget(
          wrap(
            const Column(
              children: [
                MSPageHeader(title: 'Glass', size: MSPageHeaderSize.compact),
              ],
            ),
          ),
        );
        expect(fillOf('Glass').a, moreOrLessEquals(0.8, epsilon: 0.01));

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(highContrast: true),
              child: WindTheme(
                data: WindThemeData(),
                child: const Scaffold(
                  body: Column(
                    children: [
                      MSPageHeader(
                        title: 'Solid',
                        size: MSPageHeaderSize.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(fillOf('Solid').a, 1.0);
      },
    );

    testWidgets('compact turns opaque and unblurred under high contrast', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: WindTheme(
              data: WindThemeData(),
              child: const Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: MSPageHeader(
                    title: 'Solid',
                    size: MSPageHeaderSize.compact,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is WDiv &&
              w.className ==
                  const MagicStarterPageHeaderTheme().compactBarOpaqueClassName,
        ),
        findsOneWidget,
      );
    });

    testWidgets('a zero blur sigma adds no backdrop layer', (tester) async {
      MagicStarter.usePageHeaderTheme(
        const MagicStarterPageHeaderTheme(compactBarBlurSigma: 0),
      );

      await tester.pumpWidget(
        wrap(
          const Align(
            alignment: Alignment.topCenter,
            child: MSPageHeader(title: 'Flat', size: MSPageHeaderSize.compact),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('compact clears the top safe area below its fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 47)),
            child: WindTheme(
              data: WindThemeData(),
              child: const Align(
                alignment: Alignment.topCenter,
                child: MSPageHeader(
                  title: 'Notch',
                  size: MSPageHeaderSize.compact,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.getTopLeft(find.byType(NavigationToolbar)).dy, 47);
      expect(
        tester.getSize(find.byType(MSPageHeader)).height,
        greaterThanOrEqualTo(47 + MSPageHeader.compactBarHeight),
      );
    });

    testWidgets('the compact title is a heading for assistive technology', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrap(
          const Align(
            alignment: Alignment.topCenter,
            child: MSPageHeader(title: 'Heard', size: MSPageHeaderSize.compact),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Heard')),
        matchesSemantics(label: 'Heard', isHeader: true),
      );
      handle.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Heading semantics: heading navigation finds the page title in every size.
  // ---------------------------------------------------------------------------

  group('title semantics', () {
    for (final MSPageHeaderSize size in [
      MSPageHeaderSize.regular,
      MSPageHeaderSize.large,
    ]) {
      testWidgets('the ${size.name} title is a heading', (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(wrap(MSPageHeader(title: 'Heard', size: size)));

        expect(
          tester.getSemantics(find.text('Heard')),
          matchesSemantics(label: 'Heard', isHeader: true),
        );
        handle.dispose();
      });
    }

    testWidgets('the subtitle and the actions are not headings', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrap(
          MSPageHeader(
            title: 'Heard',
            subtitle: 'Not a heading',
            actions: [TextButton(onPressed: () {}, child: const Text('Save'))],
          ),
        ),
      );

      expect(
        _headerNodes(
          tester,
        ).map((SemanticsNode n) => n.getSemanticsData().label),
        ['Heard'],
      );
      handle.dispose();
    });

    testWidgets('a heading scope takes the role off the title and no more', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrap(
          const MSPageHeaderHeadingScope(
            isHeading: false,
            child: MSPageHeader(title: 'Heard', subtitle: 'Still read'),
          ),
        ),
      );

      expect(_headerNodes(tester), isEmpty);
      expect(
        tester.getSemantics(find.text('Heard')),
        matchesSemantics(label: 'Heard'),
      );
      expect(
        tester.getSemantics(find.text('Still read')),
        matchesSemantics(label: 'Still read'),
      );
      handle.dispose();
    });

    testWidgets('a heading scope that says so leaves the title a heading', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrap(
          const MSPageHeaderHeadingScope(
            isHeading: true,
            child: MSPageHeader(title: 'Heard'),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Heard')),
        matchesSemantics(label: 'Heard', isHeader: true),
      );
      handle.dispose();
    });
  });
}

/// Every button node the platform would receive.
///
/// A node with `isMergedIntoParent` is folded into its parent and never sent to
/// assistive technology, so counting one reports a control that does not exist.
List<SemanticsNode> _buttonNodes(WidgetTester tester) {
  final List<SemanticsNode> found = <SemanticsNode>[];

  void walk(SemanticsNode node) {
    if (!node.isMergedIntoParent &&
        node.getSemanticsData().flagsCollection.isButton) {
      found.add(node);
    }
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(tester.getSemantics(find.byType(MaterialApp)));

  return found;
}

/// Every heading node the platform would receive, in tree order.
///
/// A node folded into its parent, or flagged hidden because a scroll view has
/// moved it out of the viewport, is never sent to assistive technology, so
/// counting one reports a heading nobody can reach.
List<SemanticsNode> _headerNodes(WidgetTester tester) {
  final List<SemanticsNode> found = <SemanticsNode>[];

  void walk(SemanticsNode node) {
    final SemanticsFlags flags = node.getSemanticsData().flagsCollection;
    if (!node.isMergedIntoParent && flags.isHeader && !flags.isHidden) {
      found.add(node);
    }
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(tester.getSemantics(find.byType(MaterialApp)));

  return found;
}
