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
      wrap(const ErrorState(title: 'Something went wrong')),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('ErrorState renders description when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ErrorState(
          title: 'Error',
          description: 'Please try again later',
        ),
      ),
    );
    expect(find.text('Please try again later'), findsOneWidget);
  });

  testWidgets('ErrorState renders icon when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ErrorState(
          title: 'Error',
          icon: Icons.error_outline,
        ),
      ),
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('ErrorState renders action widget when provided', (tester) async {
    const actionKey = Key('error-action');
    await tester.pumpWidget(
      wrap(
        ErrorState(
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

  testWidgets('ErrorState title uses destructive tone', (tester) async {
    await tester.pumpWidget(
      wrap(const ErrorState(title: 'Failed')),
    );
    final texts = tester.widgetList<WText>(find.byType(WText)).toList();
    // Title should use a destructive/error tone class
    expect(
      texts.any(
        (t) =>
            t.data == 'Failed' &&
            (t.className?.contains('red') == true ||
                t.className?.contains('destructive') == true),
      ),
      isTrue,
    );
  });

  testWidgets('ErrorState preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const ErrorStatePreview()));
    await tester.pump();
    expect(find.byType(ErrorStatePreview), findsOneWidget);
  });
}
