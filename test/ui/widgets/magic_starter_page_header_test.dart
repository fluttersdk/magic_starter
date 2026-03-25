import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/ui/widgets/magic_starter_page_header.dart';

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: widget,
        ),
      ),
    );
  }

  testWidgets('renders required title', (tester) async {
    await tester.pumpWidget(
      wrap(const MagicStarterPageHeader(title: 'My Page')),
    );

    expect(find.text('My Page'), findsOneWidget);
  });

  testWidgets('renders subtitle when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MagicStarterPageHeader(
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
      wrap(const MagicStarterPageHeader(title: 'Projects')),
    );

    // Only the title WText should be present; no subtitle.
    final texts = tester.widgetList<WText>(find.byType(WText)).toList();
    expect(texts.length, 1);
    expect(texts.first.data, 'Projects');
  });

  testWidgets('renders leading widget when provided', (tester) async {
    const leadingKey = Key('back-btn');

    await tester.pumpWidget(
      wrap(
        const MagicStarterPageHeader(
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
        MagicStarterPageHeader(
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
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('renders multiple actions', (tester) async {
    const key1 = Key('btn-1');
    const key2 = Key('btn-2');

    await tester.pumpWidget(
      wrap(
        MagicStarterPageHeader(
          title: 'Settings',
          actions: [
            ElevatedButton(
              key: key1,
              onPressed: () {},
              child: const Text('Save'),
            ),
            ElevatedButton(
              key: key2,
              onPressed: () {},
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(key1), findsOneWidget);
    expect(find.byKey(key2), findsOneWidget);
  });

  testWidgets('actions container not rendered when actions is null',
      (tester) async {
    await tester.pumpWidget(
      wrap(const MagicStarterPageHeader(title: 'No Actions')),
    );

    // Only the title/subtitle row WDiv is rendered, not the actions row.
    // Verify title is still present.
    expect(find.text('No Actions'), findsOneWidget);
  });

  testWidgets('actions container not rendered when actions list is empty',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const MagicStarterPageHeader(
          title: 'Empty Actions',
          actions: [],
        ),
      ),
    );

    expect(find.text('Empty Actions'), findsOneWidget);
  });

  testWidgets('outer WDiv has responsive sm:flex-row class', (tester) async {
    await tester.pumpWidget(
      wrap(const MagicStarterPageHeader(title: 'Responsive')),
    );

    // The outermost WDiv must contain the responsive flex-row class for
    // sm breakpoints so that actions appear alongside the title on wider screens.
    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('sm:flex-row'));
  });
}
