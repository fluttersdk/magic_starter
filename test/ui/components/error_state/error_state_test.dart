import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/error_state/error_state.preview.dart';

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

  testWidgets('ErrorState renders title', (tester) async {
    await tester.pumpWidget(
      wrap(const MSErrorState(title: 'Something went wrong')),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('ErrorState renders description when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSErrorState(
          title: 'Error',
          description: 'Please try again later',
        ),
      ),
    );
    expect(find.text('Please try again later'), findsOneWidget);
  });

  testWidgets('ErrorState renders icon when provided', (tester) async {
    await tester.pumpWidget(
      wrap(const MSErrorState(title: 'Error', icon: Icons.error_outline)),
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('ErrorState renders action widget when provided', (tester) async {
    const actionKey = Key('error-action');
    await tester.pumpWidget(
      wrap(
        MSErrorState(
          title: 'Error',
          action: ElevatedButton(
            key: actionKey,
            onPressed: () {},
            child: const Text('Retry'),
          ),
        ),
      ),
    );
    expect(find.byKey(actionKey), findsOneWidget);
  });

  testWidgets('ErrorState title renders an actually resolved error colour', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSErrorState(title: 'Failed')));

    // Asserts the RENDERED colour, not the className. A substring check on
    // "red" or "destructive" cannot tell a resolvable token from one Wind
    // claims and then drops: `text-destructive` looks semantic but is not in
    // the alias contract (which ships bg-destructive / text-on-destructive
    // only), so it resolves to no colour at all. That failure is invisible to
    // any assertion on the class string.
    final Text title = tester.widget<Text>(
      find.descendant(
        of: find.byType(MSErrorState),
        matching: find.text('Failed'),
      ),
    );

    expect(
      title.style?.color,
      isNotNull,
      reason: 'the title colour token resolved to nothing',
    );
    expect(title.style?.color, isNot(const Color(0xFF000000)));
  });

  testWidgets('ErrorState preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const ErrorStatePreview()));
    await tester.pump();
    expect(find.byType(ErrorStatePreview), findsOneWidget);
  });

  testWidgets('centres on the page inside a start-aligned column', (
    tester,
  ) async {
    // Like MSEmptyState, it shrank to its text in a start-aligned page body
    // and sat against the left edge.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        WDiv(
          className: 'flex flex-col gap-6',
          children: const [MSErrorState(title: 'Could not load')],
        ),
      ),
    );

    expect(tester.getCenter(find.text('Could not load')).dx, closeTo(600, 1));
  });
}
