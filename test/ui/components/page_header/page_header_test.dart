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
  // Behavior equivalence gate — mirrors magic_starter_page_header_test.dart
  // ---------------------------------------------------------------------------

  testWidgets('renders required title', (tester) async {
    await tester.pumpWidget(
      wrap(const PageHeader(title: 'My Page')),
    );
    expect(find.text('My Page'), findsOneWidget);
  });

  testWidgets('renders subtitle when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PageHeader(
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
      wrap(const PageHeader(title: 'Projects')),
    );
    final texts = tester.widgetList<WText>(find.byType(WText)).toList();
    expect(texts.length, 1);
    expect(texts.first.data, 'Projects');
  });

  testWidgets('renders leading widget when provided', (tester) async {
    const leadingKey = Key('back-btn');
    await tester.pumpWidget(
      wrap(
        const PageHeader(
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
        PageHeader(
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
      wrap(const PageHeader(title: 'Responsive')),
    );
    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('sm:flex-row'));
  });

  testWidgets('titleSuffix renders inline after title when provided',
      (tester) async {
    const suffixKey = Key('test_suffix');
    await tester.pumpWidget(
      wrap(
        PageHeader(
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
        PageHeader(
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
        PageHeader(
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
        wrap(const PageHeader(title: 'My Page')),
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
          const PageHeader(
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

  testWidgets('renders back leading when backLabel is set', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PageHeader(
          title: 'Profile',
          backLabel: 'Settings',
        ),
      ),
    );
    // Back label text must be visible.
    expect(find.text('Settings'), findsOneWidget);
    // Chevron icon is rendered.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('no back leading when backLabel is null', (tester) async {
    await tester.pumpWidget(
      wrap(const PageHeader(title: 'Dashboard')),
    );
    // Without backLabel the chevron must not appear.
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('tap on back leading invokes MagicRoute.back with fallback',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const PageHeader(
          title: 'Profile',
          backLabel: 'Settings',
          backFallback: '/settings',
        ),
      ),
    );

    // Precondition: back control renders.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    // Act: tap the back control (WAnchor wraps the chevron + label row).
    // MagicRouter is not initialized in widget tests so we expect a StateError.
    // The StateError confirms that MagicRoute.back() was actually invoked
    // (the wrong behavior would be silence — no exception, no call).
    await tester.tap(find.text('Settings'));
    await tester.pump();

    // Consume the expected StateError from the uninitialized router.
    final Object? exception = tester.takeException();
    expect(exception, isA<StateError>());
    expect(
      (exception as StateError).message,
      contains('Router not initialized'),
    );
  });
}
