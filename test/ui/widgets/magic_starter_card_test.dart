import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/ui/widgets/magic_starter_card.dart';

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

  testWidgets('MagicStarterCard renders child correctly',
      (WidgetTester tester) async {
    const childKey = Key('test-child');

    await tester.pumpWidget(
      wrap(
        const MagicStarterCard(
          child: SizedBox(key: childKey),
        ),
      ),
    );

    expect(find.byKey(childKey), findsOneWidget);
    expect(find.byType(WText), findsNothing);
  });

  testWidgets('MagicStarterCard renders title when provided',
      (WidgetTester tester) async {
    const title = 'Test Title';

    await tester.pumpWidget(
      wrap(
        const MagicStarterCard(
          title: title,
          child: SizedBox(),
        ),
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(find.byType(WText), findsOneWidget);
  });

  testWidgets('MagicStarterCard uses custom className when provided',
      (WidgetTester tester) async {
    const customClassName = 'custom-class';

    await tester.pumpWidget(
      wrap(
        const MagicStarterCard(
          className: customClassName,
          child: SizedBox(),
        ),
      ),
    );

    final wDiv = tester.widget<WDiv>(find.byType(WDiv));
    expect(wDiv.className, contains(customClassName));
  });
}
