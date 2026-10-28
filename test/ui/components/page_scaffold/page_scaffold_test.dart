import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/facades/magic_starter.dart';
import 'package:magic_starter/src/configuration/magic_starter_theme.dart';
import 'package:magic_starter/src/magic_starter_manager.dart';
import 'package:magic_starter/src/ui/components/page_container/page_container.dart';
import 'package:magic_starter/src/ui/components/page_header/page_header.dart';
import 'package:magic_starter/src/ui/components/page_scaffold/page_scaffold.dart';
import 'package:magic_starter/src/ui/components/page_scaffold/page_scaffold.recipe.dart';
import 'package:magic_starter/src/ui/components/page_scaffold/page_scaffold.preview.dart';

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
        child: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Recipe assertions (pure unit tests — no widget pump required)
  // -------------------------------------------------------------------------

  group('PageScaffoldRecipe', () {
    test('surface recipe emits w-full token', () {
      final cls = pageScaffoldSurfaceRecipe();
      expect(cls, contains('w-full'));
    });

    // The geometry itself now belongs to MSPageContainer and arrives from the
    // host; what stays asserted here is that the fallback the starter ships is
    // a COMPLETE page geometry. A consumer that configures nothing still has to
    // get a capped, edge-padded, vertically-rhythmic page.
    test('the default host geometry caps the page width', () {
      const cls = MagicStarterManager.defaultPageContainerClassName;
      expect(cls, contains('max-w-'));
    });

    test('the default host geometry emits horizontal edge margins', () {
      const cls = MagicStarterManager.defaultPageContainerClassName;
      expect(cls, contains('px-4'));
      expect(cls, contains('lg:px-8'));
    });

    // A page owns its own top offset: the app layout's content region is a bare
    // scroll view with no padding, so a geometry with no `pt-*` glued every
    // page header to the top edge of the viewport.
    test('the default host geometry emits the page top padding', () {
      const cls = MagicStarterManager.defaultPageContainerClassName;
      expect(cls, contains('pt-6'));
      expect(cls, contains('sm:pt-8'));
    });

    test('the default host geometry emits a bottom padding', () {
      const cls = MagicStarterManager.defaultPageContainerClassName;
      expect(cls, contains('pb-16'));
    });

    test('children area recipe emits mt-6 token', () {
      final cls = pageScaffoldChildrenAreaRecipe();
      expect(cls, contains('mt-6'));
    });

    test('children area recipe emits flex-col token', () {
      final cls = pageScaffoldChildrenAreaRecipe();
      expect(cls, contains('flex-col'));
    });

    test('children area recipe emits gap-6 token', () {
      final cls = pageScaffoldChildrenAreaRecipe();
      expect(cls, contains('gap-6'));
    });
  });

  // -------------------------------------------------------------------------
  // Widget tests
  // -------------------------------------------------------------------------

  testWidgets('PageScaffold renders title via PageHeader', (tester) async {
    await tester.pumpWidget(
      wrap(const MSPageScaffold(title: 'Profile', children: [])),
    );
    // PageHeader renders the title as a WText.
    final titleTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.data == 'Profile')
        .toList();
    expect(titleTexts, isNotEmpty);
  });

  testWidgets('PageScaffold renders icon-only back via PageHeader', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MSPageScaffold(
          title: 'Profile',
          backLabel: 'Settings',
          backFallback: '/settings',
          children: [],
        ),
      ),
    );
    // Icon-only back: chevron renders, parent label text is NOT shown.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('PageScaffold renders no back when backLabel is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MSPageScaffold(title: 'Settings', children: [])),
    );
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('PageScaffold renders child widgets', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSPageScaffold(
          title: 'Profile',
          children: [Text('Section 1'), Text('Section 2')],
        ),
      ),
    );
    expect(find.text('Section 1'), findsOneWidget);
    expect(find.text('Section 2'), findsOneWidget);
  });

  testWidgets('PageScaffold children area uses gap-6 column className', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MSPageScaffold(title: 'Profile', children: [Text('Child')])),
    );
    // The children-area WDiv must carry `gap-6` and `flex-col`.
    final childArea = tester
        .widgetList<WDiv>(find.byType(WDiv))
        .where(
          (w) =>
              w.className?.contains('gap-6') == true &&
              w.className?.contains('flex-col') == true,
        )
        .toList();
    expect(childArea, isNotEmpty);
  });

  testWidgets('PageScaffold outer container has the default cap and mx-auto', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MSPageScaffold(title: 'Profile', children: [])),
    );
    // The centered constrained column WDiv must carry both tokens.
    final constrainedDivs = tester
        .widgetList<WDiv>(find.byType(WDiv))
        .where(
          (w) =>
              w.className?.contains(
                    MagicStarterManager.defaultPageContainerClassName,
                  ) ==
                  true &&
              w.className?.contains('mx-auto') == true,
        )
        .toList();
    expect(constrainedDivs, isNotEmpty);
  });

  // A host app caps its own pages at its own width. When the scaffold ignored
  // that and always capped at its default, every settings header started tens
  // of pixels further out than every other page in the same app on a wide
  // window: same sidebar, same chrome, two different content columns.
  testWidgets('PageScaffold caps at the width the host configured', (
    tester,
  ) async {
    MagicStarter.manager.pageContainerClassName = 'max-w-6xl';

    await tester.pumpWidget(
      wrap(const MSPageScaffold(title: 'Profile', children: [])),
    );

    final constrainedDivs = tester
        .widgetList<WDiv>(find.byType(WDiv))
        .where((w) => w.className?.contains('max-w-6xl') == true)
        .toList();
    expect(constrainedDivs, isNotEmpty);
  });

  // A pushed screen puts its own bar above the scaffold, so the host's top
  // padding stacks on the bar's height and the title sits far under it. The
  // scaffold therefore takes a className for its container, appended after the
  // host's geometry like MSPageContainer's own.
  testWidgets('PageScaffold containerClassName replaces the host top padding', (
    tester,
  ) async {
    MagicStarter.manager.pageContainerClassName = 'max-w-6xl pt-8';

    double titleTop() => tester.getTopLeft(find.text('Profile')).dy;

    await tester.pumpWidget(
      wrap(const MSPageScaffold(title: 'Profile', children: [])),
    );
    final double hostTop = titleTop();

    await tester.pumpWidget(
      wrap(
        const MSPageScaffold(
          title: 'Profile',
          containerClassName: 'pt-4',
          children: [],
        ),
      ),
    );
    final double overriddenTop = titleTop();

    expect(
      hostTop - overriddenTop,
      16,
      reason: 'pt-4 (16) replaces the host pt-8 (32) at every width',
    );
  });

  testWidgets('PageScaffold uses SingleChildScrollView with primary: false', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MSPageScaffold(title: 'Profile', children: [])),
    );
    // There must be exactly one non-primary SingleChildScrollView
    // (primary: false is required to avoid PrimaryScrollController contention).
    final scrollViews = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((sv) => sv.primary == false)
        .toList();
    expect(scrollViews, isNotEmpty);
  });

  testWidgets('PageScaffold renders subtitle via PageHeader when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MSPageScaffold(
          title: 'Profile',
          subtitle: 'Manage your account',
          children: [],
        ),
      ),
    );
    final subtitleTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.data == 'Manage your account')
        .toList();
    expect(subtitleTexts, isNotEmpty);
  });

  // A page-level action belongs in the shared header next to the title. Before
  // the scaffold forwarded them, a page that needed one (Notifications and its
  // "mark all read") had to build its own header, and building its own header
  // is how it ended up building its own container too.
  testWidgets('PageScaffold renders header actions when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MSPageScaffold(
          title: 'Notifications',
          actions: [Text('Mark all read')],
          children: [],
        ),
      ),
    );

    expect(find.text('Mark all read'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Docked footer slot
  // -------------------------------------------------------------------------

  group('PageScaffold footer', () {
    const footerKey = Key('composer');
    const phone = Size(390, 844);

    // A bounded page, as the app shell hands one over. The Scaffold must not
    // resize for the keyboard itself, otherwise it would absorb the inset
    // before the scaffold under test ever sees it.
    Widget docked(Widget widget) {
      return MaterialApp(
        home: WindTheme(
          data: WindThemeData(),
          child: Scaffold(resizeToAvoidBottomInset: false, body: widget),
        ),
      );
    }

    List<Widget> messages() => List<Widget>.generate(
      40,
      (int i) => SizedBox(height: 60, child: Text('Message $i')),
    );

    void setViewport(WidgetTester tester, {double keyboard = 0}) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = phone;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.reset);
    }

    testWidgets('footer stays at the viewport bottom with long content', (
      tester,
    ) async {
      setViewport(tester);

      await tester.pumpWidget(
        docked(
          MSPageScaffold(
            title: 'Thread',
            footer: const SizedBox(key: footerKey, height: 56),
            children: messages(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getBottomLeft(find.byKey(footerKey)).dy, phone.height);
    });

    testWidgets('footer sits inside the same width container as the page', (
      tester,
    ) async {
      setViewport(tester);

      await tester.pumpWidget(
        docked(
          MSPageScaffold(
            title: 'Thread',
            footer: const SizedBox(key: footerKey, height: 56),
            children: messages(),
          ),
        ),
      );

      final containers = find.ancestor(
        of: find.byKey(footerKey),
        matching: find.byType(MSPageContainer),
      );
      expect(containers, findsOneWidget);
    });

    testWidgets('footer rises above the keyboard inset', (tester) async {
      setViewport(tester, keyboard: 300);

      await tester.pumpWidget(
        docked(
          MSPageScaffold(
            title: 'Thread',
            footer: const SizedBox(key: footerKey, height: 56),
            children: messages(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(find.byKey(footerKey)).dy,
        lessThanOrEqualTo(phone.height - 300),
      );
    });

    testWidgets('footer is outside the scroll view', (tester) async {
      setViewport(tester);

      await tester.pumpWidget(
        docked(
          MSPageScaffold(
            title: 'Thread',
            footer: const SizedBox(key: footerKey, height: 56),
            children: messages(),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byKey(footerKey),
        ),
        findsNothing,
      );
    });

    testWidgets('scrollController drives the scrolling area', (tester) async {
      setViewport(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        docked(
          MSPageScaffold(
            title: 'Thread',
            scrollController: controller,
            footer: const SizedBox(key: footerKey, height: 56),
            children: messages(),
          ),
        ),
      );

      expect(controller.hasClients, isTrue);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.offset, greaterThan(0));
    });

    testWidgets('no footer leaves no docked layout in the tree', (
      tester,
    ) async {
      setViewport(tester);

      await tester.pumpWidget(
        wrap(const MSPageScaffold(title: 'Thread', children: [Text('Body')])),
      );

      expect(find.byKey(footerKey), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MSPageScaffold),
          matching: find.byType(Expanded),
        ),
        findsNothing,
      );
    });
  });

  testWidgets('PageScaffoldPreview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const PageScaffoldPreview()));
    await tester.pump();
    expect(find.byType(PageScaffoldPreview), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Large title
  // -------------------------------------------------------------------------

  group('large title', () {
    // A bounded page, as the app shell gives one: the scaffold owns the scroll.
    Widget page(Widget scaffold, {MediaQueryData? media}) {
      final Widget app = MaterialApp(
        home: WindTheme(
          data: WindThemeData(),
          child: Scaffold(body: scaffold),
        ),
      );

      return media == null ? app : MediaQuery(data: media, child: app);
    }

    const List<Widget> tallBody = [SizedBox(height: 2000)];

    Finder bar() => find.byWidgetPredicate(
      (w) => w is MSPageHeader && w.size == MSPageHeaderSize.compact,
    );

    testWidgets('renders a large header and no bar at the top', (tester) async {
      await tester.pumpWidget(
        page(
          const MSPageScaffold(
            title: 'Stock',
            largeTitle: true,
            children: tallBody,
          ),
        ),
      );

      final MSPageHeader header = tester.widget<MSPageHeader>(
        find.byType(MSPageHeader),
      );
      expect(header.size, MSPageHeaderSize.large);
      expect(bar(), findsNothing);
      expect(find.text('Stock'), findsOneWidget);
    });

    testWidgets('the bar fades in once the header has scrolled away', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          const MSPageScaffold(
            title: 'Stock',
            largeTitle: true,
            children: tallBody,
          ),
        ),
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(bar(), findsOneWidget);
      expect(tester.getTopLeft(bar()).dy, 0);
      final FadeTransition fade = tester.widget<FadeTransition>(
        find.ancestor(of: bar(), matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 1.0);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: bar(), matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isFalse,
      );
    });

    testWidgets('the bar stays away while the header is still in view', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          const MSPageScaffold(
            title: 'Stock',
            largeTitle: true,
            children: tallBody,
          ),
        ),
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -10),
      );
      await tester.pumpAndSettle();

      expect(bar(), findsNothing);
    });

    testWidgets('scrolling back to the top fades the bar out and unmounts it', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          const MSPageScaffold(
            title: 'Stock',
            largeTitle: true,
            children: tallBody,
          ),
        ),
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Mid-fade: still mounted, no longer tappable.
      expect(bar(), findsOneWidget);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: bar(), matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
      );

      await tester.pumpAndSettle();
      expect(bar(), findsNothing);
      expect(find.text('Stock'), findsOneWidget);
    });

    testWidgets('Reduce Motion swaps the bar in without a fade', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          const MSPageScaffold(
            title: 'Stock',
            largeTitle: true,
            children: tallBody,
          ),
          media: const MediaQueryData(
            size: Size(800, 600),
            disableAnimations: true,
          ),
        ),
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pump();
      await tester.pump();

      final FadeTransition fade = tester.widget<FadeTransition>(
        find.ancestor(of: bar(), matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 1.0);
    });

    testWidgets('a horizontal list inside the page does not collapse it', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          MSPageScaffold(
            title: 'Stock',
            largeTitle: true,
            children: [
              SizedBox(
                height: 80,
                child: ListView(
                  key: const Key('carousel'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (int i = 0; i < 20; i++)
                      SizedBox(width: 120, child: Text('Card $i')),
                  ],
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      );

      await tester.drag(
        find.byKey(const Key('carousel')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      expect(bar(), findsNothing);
    });

    testWidgets('the bar carries the back control and the actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          MSPageScaffold(
            title: 'Milk',
            largeTitle: true,
            backLabel: 'Stock',
            backFallback: '/stock',
            actions: [TextButton(onPressed: () {}, child: const Text('Edit'))],
            children: tallBody,
          ),
        ),
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: bar(), matching: find.byIcon(Icons.chevron_left)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar(), matching: find.text('Edit')),
        findsOneWidget,
      );
    });

    testWidgets('the theme makes every scaffold a large title', (tester) async {
      MagicStarter.usePageHeaderTheme(
        const MagicStarterPageHeaderTheme(largeTitle: true),
      );

      await tester.pumpWidget(
        page(const MSPageScaffold(title: 'Settings', children: tallBody)),
      );

      expect(
        tester.widget<MSPageHeader>(find.byType(MSPageHeader)).size,
        MSPageHeaderSize.large,
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(bar(), findsOneWidget);
    });

    testWidgets('an explicit false beats a large theme', (tester) async {
      MagicStarter.usePageHeaderTheme(
        const MagicStarterPageHeaderTheme(largeTitle: true),
      );

      await tester.pumpWidget(
        page(
          const MSPageScaffold(
            title: 'Settings',
            largeTitle: false,
            children: tallBody,
          ),
        ),
      );

      expect(
        tester.widget<MSPageHeader>(find.byType(MSPageHeader)).size,
        MSPageHeaderSize.regular,
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(bar(), findsNothing);
    });

    testWidgets('the default stays the regular header with no bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(const MSPageScaffold(title: 'Plain', children: tallBody)),
      );

      expect(
        tester.widget<MSPageHeader>(find.byType(MSPageHeader)).size,
        MSPageHeaderSize.regular,
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(bar(), findsNothing);
    });

    // Heading navigation reads the semantics tree, so the invariant is one
    // heading per title the reader can see: the large title while it is on
    // screen, the bar's once the bar has taken over, never both.
    group('heading semantics', () {
      Finder largeHeader() => find.byWidgetPredicate(
        (w) => w is MSPageHeader && w.size == MSPageHeaderSize.large,
      );

      List<String> headings(WidgetTester tester) => _headerNodes(
        tester,
      ).map((SemanticsNode n) => n.getSemanticsData().label).toList();

      testWidgets('the large title is the page heading', (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(
          page(
            const MSPageScaffold(
              title: 'Stock',
              largeTitle: true,
              children: tallBody,
            ),
          ),
        );

        expect(headings(tester), ['Stock']);
        handle.dispose();
      });

      testWidgets('the regular title is the page heading', (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(
          page(const MSPageScaffold(title: 'Plain', children: tallBody)),
        );

        expect(headings(tester), ['Plain']);
        handle.dispose();
      });

      testWidgets('the bar is the only heading once it has taken over', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(
          page(
            const MSPageScaffold(
              title: 'Stock',
              largeTitle: true,
              children: tallBody,
            ),
          ),
        );
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();

        expect(bar(), findsOneWidget);
        expect(headings(tester), ['Stock']);
        handle.dispose();
      });

      testWidgets('a large title still partly on screen behind the bar is not '
          'a second heading', (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          page(
            MSPageScaffold(
              title: 'Stock',
              largeTitle: true,
              scrollController: controller,
              children: tallBody,
            ),
          ),
        );

        // Park the header's bottom edge 4 px under the bar's: collapsed, while
        // the header's own box still reaches into the viewport.
        final double headerBottom = tester.getBottomLeft(largeHeader()).dy;
        controller.jumpTo(headerBottom - (MSPageHeader.compactBarHeight - 4));
        await tester.pumpAndSettle();

        expect(bar(), findsOneWidget);
        expect(tester.getBottomLeft(largeHeader()).dy, greaterThan(0));
        expect(headings(tester), ['Stock']);
        handle.dispose();
      });

      testWidgets('a bar fading out is not a second heading', (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(
          page(
            const MSPageScaffold(
              title: 'Stock',
              largeTitle: true,
              children: tallBody,
            ),
          ),
        );
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 400),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Mid-fade: the bar is still mounted and the large title is back.
        expect(bar(), findsOneWidget);
        expect(largeHeader(), findsOneWidget);
        expect(headings(tester), ['Stock']);
        handle.dispose();
      });

      testWidgets('Reduce Motion keeps one heading at both ends', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(
          page(
            const MSPageScaffold(
              title: 'Stock',
              largeTitle: true,
              children: tallBody,
            ),
            media: const MediaQueryData(
              size: Size(800, 600),
              disableAnimations: true,
            ),
          ),
        );
        expect(headings(tester), ['Stock']);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pump();
        await tester.pump();

        expect(bar(), findsOneWidget);
        expect(headings(tester), ['Stock']);
        handle.dispose();
      });

      // The bar has no subtitle, so the subtitle is the one thing only the
      // large header says; it must not leave the tree with the heading role.
      testWidgets(
        'the subtitle stays in the tree once the bar has taken over',
        (tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          final ScrollController controller = ScrollController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            page(
              MSPageScaffold(
                title: 'Stock',
                subtitle: 'Everything you own',
                largeTitle: true,
                scrollController: controller,
                children: tallBody,
              ),
            ),
          );
          expect(_visibleLabels(tester), contains('Everything you own'));

          final double headerBottom = tester.getBottomLeft(largeHeader()).dy;
          controller.jumpTo(headerBottom - (MSPageHeader.compactBarHeight - 4));
          await tester.pumpAndSettle();

          expect(bar(), findsOneWidget);
          expect(_visibleLabels(tester), contains('Everything you own'));
          expect(headings(tester), ['Stock']);
          handle.dispose();
        },
      );
    });

    testWidgets('a docked footer stays below the collapsing page', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          const MSPageScaffold(
            title: 'Thread',
            largeTitle: true,
            footer: Text('composer'),
            children: tallBody,
          ),
        ),
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(bar(), findsOneWidget);
      expect(find.text('composer'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('composer')).dy,
        greaterThan(tester.getBottomLeft(bar()).dy),
      );
    });
  });
}

/// The label of every node the platform would receive, in tree order.
///
/// Folded and hidden nodes are skipped for the reason [_headerNodes] gives.
List<String> _visibleLabels(WidgetTester tester) {
  final List<String> found = <String>[];

  void walk(SemanticsNode node) {
    final SemanticsData data = node.getSemanticsData();
    if (!node.isMergedIntoParent && !data.flagsCollection.isHidden) {
      found.add(data.label);
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
