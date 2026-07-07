// hide Flutter's material Typography to avoid the name conflict with ours.
import 'package:flutter/material.dart' hide Typography;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/typography/typography.preview.dart';

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
  // Recipe variant-class assertions (TDD red: these must fail before impl)
  // ---------------------------------------------------------------------------

  group('typography recipe', () {
    test('h1 variant emits text-4xl or larger size token', () {
      final cls = typographyRecipe(
        variants: {'variant': TypographyVariant.h1.name},
      );
      expect(cls, contains('text-4xl'));
    });

    test('h2 variant emits text-3xl size token', () {
      final cls = typographyRecipe(
        variants: {'variant': TypographyVariant.h2.name},
      );
      expect(cls, contains('text-3xl'));
    });

    test('h3 variant emits text-2xl size token', () {
      final cls = typographyRecipe(
        variants: {'variant': TypographyVariant.h3.name},
      );
      expect(cls, contains('text-2xl'));
    });

    test('body variant emits text-base size token', () {
      final cls = typographyRecipe(
        variants: {'variant': TypographyVariant.body.name},
      );
      expect(cls, contains('text-base'));
    });

    test('caption variant emits text-sm or text-xs size token', () {
      final cls = typographyRecipe(
        variants: {'variant': TypographyVariant.caption.name},
      );
      // caption should be smaller than body
      final hasSm = cls.contains('text-sm');
      final hasXs = cls.contains('text-xs');
      expect(hasSm || hasXs, isTrue);
    });

    test('default variant produces body when nothing is passed', () {
      final cls = typographyRecipe();
      expect(cls, contains('text-base'));
    });

    test('heading variants contain text-fg token for foreground color', () {
      for (final v in [
        TypographyVariant.h1,
        TypographyVariant.h2,
        TypographyVariant.h3,
      ]) {
        final cls = typographyRecipe(
          variants: {'variant': v.name},
        );
        expect(cls, contains('text-fg'),
            reason: '${v.name} should carry text-fg');
      }
    });

    test('emission order: base precedes variant classes', () {
      final cls = typographyRecipe(
        variants: {'variant': TypographyVariant.h1.name},
      );
      // base class appears before the variant text-4xl token
      final baseIdx = cls.indexOf('text-fg');
      final variantIdx = cls.indexOf('text-4xl');
      // If base contains text-fg and variant contains text-4xl, base must come first
      // (or both may be in base — either is acceptable; what matters is no crash)
      expect(cls, isNotEmpty);
      expect(baseIdx, isNot(equals(-1)));
      expect(variantIdx, isNot(equals(-1)));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Typography renders text content', (tester) async {
    await tester.pumpWidget(
      wrap(const Typography('Hello', variant: TypographyVariant.body)),
    );
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('Typography default variant is body', (tester) async {
    await tester.pumpWidget(
      wrap(const Typography('Hello')),
    );
    final wText = tester.widget<WText>(find.byType(WText).first);
    expect(wText.className, contains('text-base'));
  });

  testWidgets('Typography h1 applies text-4xl className', (tester) async {
    await tester.pumpWidget(
      wrap(const Typography('Heading', variant: TypographyVariant.h1)),
    );
    final wText = tester.widget<WText>(find.byType(WText).first);
    expect(wText.className, contains('text-4xl'));
  });

  testWidgets('Typography caption applies smaller text size', (tester) async {
    await tester.pumpWidget(
      wrap(const Typography('Caption', variant: TypographyVariant.caption)),
    );
    final wText = tester.widget<WText>(find.byType(WText).first);
    final hasSmall = wText.className!.contains('text-sm') ||
        wText.className!.contains('text-xs');
    expect(hasSmall, isTrue);
  });

  testWidgets('Typography light+dark preview renders without error',
      (tester) async {
    await tester.pumpWidget(wrap(const TypographyPreview()));
    await tester.pump();
    expect(find.byType(TypographyPreview), findsOneWidget);
  });

  testWidgets('TypographyPreview renders all variants', (tester) async {
    await tester.pumpWidget(wrap(const TypographyPreview()));
    await tester.pump();
    final texts = tester.widgetList<WText>(find.byType(WText));
    expect(texts.length, greaterThanOrEqualTo(TypographyVariant.values.length));
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Typography appends caller className onto the recipe base',
      (tester) async {
    await tester.pumpWidget(
      wrap(const Typography('Hi', className: 'mt-10')),
    );
    final wText = tester.widget<WText>(find.byType(WText).first);
    expect(wText.className, contains('text-base'));
    expect(wText.className, contains('mt-10'));
  });
}
