import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

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
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Card appends caller className onto the recipe base',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const Card(
          className: 'mt-10',
          child: Text('body'),
        ),
      ),
    );
    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('w-full'));
    expect(wDiv.className, contains('mt-10'));
  });

  testWidgets('Card without caller className keeps the recipe base',
      (tester) async {
    await tester.pumpWidget(
      wrap(const Card(child: Text('body'))),
    );
    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('w-full'));
  });
}
