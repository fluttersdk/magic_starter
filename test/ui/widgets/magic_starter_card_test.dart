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

  // -------------------------------------------------------------------------
  // CardVariant tests
  // -------------------------------------------------------------------------

  testWidgets('CardVariant.surface uses white background and border classes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const MagicStarterCard(
          variant: CardVariant.surface,
          child: SizedBox(),
        ),
      ),
    );

    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('bg-white'));
    expect(wDiv.className, contains('border'));
    expect(wDiv.className, isNot(contains('shadow-md')));
  });

  testWidgets('CardVariant.inset uses gray-50 background and border classes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const MagicStarterCard(
          variant: CardVariant.inset,
          child: SizedBox(),
        ),
      ),
    );

    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('bg-gray-50'));
    expect(wDiv.className, contains('border'));
    expect(wDiv.className, isNot(contains('shadow-md')));
  });

  testWidgets('CardVariant.elevated uses shadow-md and no border',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const MagicStarterCard(
          variant: CardVariant.elevated,
          child: SizedBox(),
        ),
      ),
    );

    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('shadow-md'));
    expect(wDiv.className, isNot(contains('border border-gray-')));
  });

  testWidgets('default variant is CardVariant.surface', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MagicStarterCard(child: SizedBox()),
      ),
    );

    final card = tester.widget<MagicStarterCard>(
      find.byType(MagicStarterCard),
    );
    expect(card.variant, CardVariant.surface);
  });

  testWidgets('CardVariant.inset with noPadding produces overflow-hidden class',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const MagicStarterCard(
          variant: CardVariant.inset,
          noPadding: true,
          child: SizedBox(),
        ),
      ),
    );

    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('overflow-hidden'));
    expect(wDiv.className, contains('bg-gray-50'));
  });

  testWidgets(
      'CardVariant.elevated with noPadding produces overflow-hidden class',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const MagicStarterCard(
          variant: CardVariant.elevated,
          noPadding: true,
          child: SizedBox(),
        ),
      ),
    );

    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('overflow-hidden'));
    expect(wDiv.className, contains('shadow-md'));
  });
}
