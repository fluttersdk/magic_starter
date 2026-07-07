import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Regression test for MS-6: components must render standalone even when
/// no `Magic.singleton('magic_starter', ...)` has been bound. Before the
/// defensive fallback in `MagicStarter.manager`, this threw
/// "Service [magic_starter] is not registered".
void main() {
  setUp(() {
    // Deliberately NO `Magic.singleton('magic_starter', ...)` call — this is
    // the whole point of the test.
    MagicApp.reset();
    Magic.flush();
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

  testWidgets('Card renders without throwing when magic_starter is unbound',
      (tester) async {
    await tester.pumpWidget(
      wrap(const MSCard(child: Text('body'))),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('body'), findsOneWidget);
  });
}
