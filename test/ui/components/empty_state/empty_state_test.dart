import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/empty_state/empty_state.preview.dart';

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

  testWidgets('EmptyState renders title', (tester) async {
    await tester.pumpWidget(wrap(const MSEmptyState(title: 'No items found')));
    expect(find.text('No items found'), findsOneWidget);
  });

  testWidgets('EmptyState renders description when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSEmptyState(
          title: 'No items',
          description: 'Start by creating one',
        ),
      ),
    );
    expect(find.text('Start by creating one'), findsOneWidget);
  });

  testWidgets('EmptyState renders icon when provided', (tester) async {
    await tester.pumpWidget(
      wrap(const MSEmptyState(title: 'No items', icon: Icons.inbox_outlined)),
    );
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('EmptyState renders action widget when provided', (tester) async {
    const actionKey = Key('empty-action');
    await tester.pumpWidget(
      wrap(
        MSEmptyState(
          title: 'No items',
          action: ElevatedButton(
            key: actionKey,
            onPressed: () {},
            child: const Text('Create'),
          ),
        ),
      ),
    );
    expect(find.byKey(actionKey), findsOneWidget);
  });

  testWidgets('EmptyState does not render description when omitted', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSEmptyState(title: 'Nothing here')));
    // Only title WText present
    final texts = tester.widgetList<WText>(find.byType(WText)).toList();
    expect(texts.any((t) => t.data == 'Nothing here'), isTrue);
  });

  testWidgets('EmptyState preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const EmptyStatePreview()));
    await tester.pump();
    expect(find.byType(EmptyStatePreview), findsOneWidget);
  });
}
