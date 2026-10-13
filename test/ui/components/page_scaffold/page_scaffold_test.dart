import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/facades/magic_starter.dart';
import 'package:magic_starter/src/magic_starter_manager.dart';
import 'package:magic_starter/src/ui/components/page_container/page_container.dart';
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
}
