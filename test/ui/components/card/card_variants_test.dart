import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Reproduces the pre-migration `_defaultClassName` interpolation verbatim.
///
/// This is the equivalence baseline the WindRecipe MUST match byte-for-byte
/// for every variant x noPadding combination. It mirrors the original widget
/// body at `magic_starter_card.dart:110-116` before the migration.
String legacyDefaultClassName(
  MagicStarterCardTheme theme,
  CardVariant variant,
  bool noPadding,
) {
  final v = switch (variant) {
    CardVariant.surface => theme.surfaceClassName,
    CardVariant.inset => theme.insetClassName,
    CardVariant.elevated => theme.elevatedClassName,
  };
  return noPadding
      ? 'w-full $v ${theme.borderRadius} overflow-hidden flex flex-col'
      : 'w-full $v ${theme.borderRadius} ${theme.paddingClassName} flex flex-col gap-4';
}

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
        child: Scaffold(
          body: widget,
        ),
      ),
    );
  }

  testWidgets('MSCard renders child correctly', (WidgetTester tester) async {
    const childKey = Key('test-child');

    await tester.pumpWidget(
      wrap(
        const MSCard(
          child: SizedBox(key: childKey),
        ),
      ),
    );

    expect(find.byKey(childKey), findsOneWidget);
    expect(find.byType(WText), findsNothing);
  });

  testWidgets('MSCard renders title when provided',
      (WidgetTester tester) async {
    const title = 'Test Title';

    await tester.pumpWidget(
      wrap(
        const MSCard(
          title: title,
          child: SizedBox(),
        ),
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(find.byType(WText), findsOneWidget);
  });

  testWidgets('MSCard uses custom className when provided',
      (WidgetTester tester) async {
    const customClassName = 'custom-class';

    await tester.pumpWidget(
      wrap(
        const MSCard(
          className: customClassName,
          child: SizedBox(),
        ),
      ),
    );

    final wDiv = tester.widget<WDiv>(find.byType(WDiv));
    expect(wDiv.className, contains(customClassName));
  });

  // -------------------------------------------------------------------------
  // WindRecipe byte-identical equivalence gate
  // -------------------------------------------------------------------------

  group('card recipe equivalence', () {
    test(
        'recipe output is byte-identical to legacy _defaultClassName for every '
        'variant x noPadding combo (default theme)', () {
      const theme = MagicStarterCardTheme();
      final recipe = buildCardRecipe(theme);

      for (final variant in CardVariant.values) {
        for (final noPadding in [false, true]) {
          final actual = recipe(
            variants: {
              kCardVariantAxis: variant.name,
              kCardPaddingAxis:
                  noPadding ? kCardPaddingNoPadding : kCardPaddingPadded,
            },
          );
          final expected = legacyDefaultClassName(theme, variant, noPadding);

          expect(
            actual,
            expected,
            reason: 'variant=$variant noPadding=$noPadding must match exactly',
          );
        }
      }
    });

    test('recipe output stays byte-identical under a custom theme', () {
      const theme = MagicStarterCardTheme(
        surfaceClassName: 'bg-zinc-900 border border-zinc-700',
        insetClassName: 'bg-zinc-800 border border-zinc-700',
        elevatedClassName: 'bg-zinc-900 shadow-lg',
        borderRadius: 'rounded-xl',
        paddingClassName: 'p-8',
      );
      final recipe = buildCardRecipe(theme);

      for (final variant in CardVariant.values) {
        for (final noPadding in [false, true]) {
          final actual = recipe(
            variants: {
              kCardVariantAxis: variant.name,
              kCardPaddingAxis:
                  noPadding ? kCardPaddingNoPadding : kCardPaddingPadded,
            },
          );
          final expected = legacyDefaultClassName(theme, variant, noPadding);

          expect(actual, expected);
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  // CardVariant tests
  // -------------------------------------------------------------------------

  testWidgets('CardVariant.surface uses white background and border classes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const MSCard(
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
        const MSCard(
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
        const MSCard(
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
        const MSCard(child: SizedBox()),
      ),
    );

    final card = tester.widget<MSCard>(
      find.byType(MSCard),
    );
    expect(card.variant, CardVariant.surface);
  });

  testWidgets('CardVariant.inset with noPadding produces overflow-hidden class',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSCard(
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
        const MSCard(
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

  // -------------------------------------------------------------------------
  // Theme consumption tests
  // -------------------------------------------------------------------------

  group('theme consumption', () {
    testWidgets('custom surfaceClassName is used for surface variant',
        (tester) async {
      MagicStarter.manager.cardTheme = const MagicStarterCardTheme(
        surfaceClassName: 'custom-surface',
      );

      await tester.pumpWidget(
        wrap(
          const MSCard(
            variant: CardVariant.surface,
            child: SizedBox(),
          ),
        ),
      );

      final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
      expect(wDiv.className, contains('custom-surface'));
    });

    testWidgets('custom titleClassName is used for card title', (tester) async {
      MagicStarter.manager.cardTheme = const MagicStarterCardTheme(
        titleClassName: 'custom-title-class',
      );

      await tester.pumpWidget(
        wrap(
          const MSCard(
            title: 'My Card',
            child: SizedBox(),
          ),
        ),
      );

      final wText = tester.widget<WText>(find.byType(WText).first);
      expect(wText.className, contains('custom-title-class'));
    });

    testWidgets('custom elevatedClassName is used for elevated variant',
        (tester) async {
      MagicStarter.manager.cardTheme = const MagicStarterCardTheme(
        elevatedClassName: 'custom-elevated',
      );

      await tester.pumpWidget(
        wrap(
          const MSCard(
            variant: CardVariant.elevated,
            child: SizedBox(),
          ),
        ),
      );

      final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
      expect(wDiv.className, contains('custom-elevated'));
    });
  });
}
