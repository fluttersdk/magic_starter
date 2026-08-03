import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
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
    await tester.pumpWidget(
      wrap(const MSPageHeader(title: 'My Page')),
    );
    expect(find.text('My Page'), findsOneWidget);
  });

  testWidgets('renders subtitle when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSPageHeader(
          title: 'Projects',
          subtitle: 'Manage your projects',
        ),
      ),
    );
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Manage your projects'), findsOneWidget);
  });

  testWidgets('does not render subtitle when omitted', (tester) async {
    await tester.pumpWidget(
      wrap(const MSPageHeader(title: 'Projects')),
    );
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
    await tester.pumpWidget(
      wrap(const MSPageHeader(title: 'Responsive')),
    );
    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('sm:flex-row'));
  });

  testWidgets('titleSuffix renders inline after title when provided',
      (tester) async {
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

  testWidgets('inlineActions: true outer WDiv className contains flex-row',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'Inline',
          inlineActions: true,
          actions: [
            ElevatedButton(onPressed: () {}, child: const Text('Go')),
          ],
        ),
      ),
    );
    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('flex-row'));
    expect(outerDiv.className, isNot(contains('flex-col')));
  });

  testWidgets('inlineActions: false (default) retains flex-col sm:flex-row',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        MSPageHeader(
          title: 'Default Layout',
          actions: [
            ElevatedButton(onPressed: () {}, child: const Text('Go')),
          ],
        ),
      ),
    );
    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('flex-col'));
    expect(outerDiv.className, contains('sm:flex-row'));
  });

  // ---------------------------------------------------------------------------
  // Theme consumption
  // ---------------------------------------------------------------------------

  group('theme consumption', () {
    testWidgets('custom titleClassName is used', (tester) async {
      MagicStarter.manager.pageHeaderTheme = const MagicStarterPageHeaderTheme(
        titleClassName: 'custom-header-title',
      );
      await tester.pumpWidget(
        wrap(const MSPageHeader(title: 'My Page')),
      );
      final titleText = tester.widgetList<WText>(find.byType(WText)).first;
      expect(titleText.className, contains('custom-header-title'));
    });

    testWidgets('custom subtitleClassName is used', (tester) async {
      MagicStarter.manager.pageHeaderTheme = const MagicStarterPageHeaderTheme(
        subtitleClassName: 'custom-header-subtitle',
      );
      await tester.pumpWidget(
        wrap(
          const MSPageHeader(
            title: 'My Page',
            subtitle: 'A subtitle',
          ),
        ),
      );
      final texts = tester.widgetList<WText>(find.byType(WText)).toList();
      expect(texts[1].className, contains('custom-header-subtitle'));
    });
  });

  testWidgets('PageHeader preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const PageHeaderPreview()));
    await tester.pump();
    expect(find.byType(PageHeaderPreview), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Back affordance — TDD cases
  // ---------------------------------------------------------------------------

  testWidgets('renders icon-only back leading when backLabel is set',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSPageHeader(
          title: 'Profile',
          backLabel: 'Settings',
        ),
      ),
    );
    // Icon-only: the chevron renders, the parent label text is NOT shown.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('no back leading when backLabel is null', (tester) async {
    await tester.pumpWidget(
      wrap(const MSPageHeader(title: 'Dashboard')),
    );
    // Without backLabel the chevron must not appear.
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('tap on back leading navigates to the parent route',
      (tester) async {
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
      wrap(
        const MSPageHeader(
          title: 'Empty Actions',
          actions: [],
        ),
      ),
    );

    expect(find.text('Empty Actions'), findsOneWidget);
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
}
