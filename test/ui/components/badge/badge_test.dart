// hide Flutter's material Badge to avoid the name conflict with our Badge.
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/badge/badge.preview.dart';

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

  group('badge recipe', () {
    test('neutral tone emits bg-surface-container-high token', () {
      final cls = badgeRecipe(
        variants: {'tone': BadgeTone.neutral.name},
      );
      expect(cls, contains('bg-surface-container-high'));
    });

    test('primary tone emits bg-primary token', () {
      final cls = badgeRecipe(
        variants: {'tone': BadgeTone.primary.name},
      );
      expect(cls, contains('bg-primary'));
    });

    test('accent tone emits bg-accent token', () {
      final cls = badgeRecipe(
        variants: {'tone': BadgeTone.accent.name},
      );
      expect(cls, contains('bg-accent'));
    });

    test('success tone emits bg-success token', () {
      final cls = badgeRecipe(
        variants: {'tone': BadgeTone.success.name},
      );
      expect(cls, contains('bg-success'));
    });

    test('warning tone emits bg-warning token', () {
      final cls = badgeRecipe(
        variants: {'tone': BadgeTone.warning.name},
      );
      expect(cls, contains('bg-warning'));
    });

    test('destructive tone emits bg-destructive token', () {
      final cls = badgeRecipe(
        variants: {'tone': BadgeTone.destructive.name},
      );
      expect(cls, contains('bg-destructive'));
    });

    test('outline tone emits border token and no solid background', () {
      final cls = badgeRecipe(
        variants: {'tone': BadgeTone.outline.name},
      );
      expect(cls, contains('border'));
      expect(cls, isNot(contains('bg-primary')));
      expect(cls, isNot(contains('bg-success')));
    });

    test('default variant produces neutral tone when nothing is passed', () {
      final cls = badgeRecipe();
      expect(cls, contains('bg-surface-container-high'));
    });

    test('emission order: base precedes variant classes', () {
      final cls = badgeRecipe(
        variants: {'tone': BadgeTone.primary.name},
      );
      final baseIdx = cls.indexOf('inline-flex');
      final variantIdx = cls.indexOf('bg-primary');
      expect(baseIdx, lessThan(variantIdx));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Badge renders label text', (tester) async {
    await tester.pumpWidget(
      wrap(const Badge('Active')),
    );
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('Badge default tone is neutral', (tester) async {
    await tester.pumpWidget(
      wrap(const Badge('Label')),
    );
    final wBadge = tester.widget<WBadge>(find.byType(WBadge));
    expect(wBadge.className, contains('bg-surface-container-high'));
  });

  testWidgets('Badge applies primary tone className', (tester) async {
    await tester.pumpWidget(
      wrap(const Badge('Label', tone: BadgeTone.primary)),
    );
    final wBadge = tester.widget<WBadge>(find.byType(WBadge));
    expect(wBadge.className, contains('bg-primary'));
  });

  testWidgets('Badge applies outline tone with border', (tester) async {
    await tester.pumpWidget(
      wrap(const Badge('Label', tone: BadgeTone.outline)),
    );
    final wBadge = tester.widget<WBadge>(find.byType(WBadge));
    expect(wBadge.className, contains('border'));
    expect(wBadge.className, isNot(contains('bg-primary')));
  });

  testWidgets('Badge light+dark preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const BadgePreview()));
    await tester.pump();
    expect(find.byType(BadgePreview), findsOneWidget);
  });

  testWidgets('BadgePreview renders all tones', (tester) async {
    await tester.pumpWidget(wrap(const BadgePreview()));
    await tester.pump();
    final badges = tester.widgetList<WBadge>(find.byType(WBadge));
    expect(badges.length, greaterThanOrEqualTo(BadgeTone.values.length));
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Badge appends caller className onto the recipe base',
      (tester) async {
    await tester.pumpWidget(
      wrap(const Badge('Label', tone: BadgeTone.primary, className: 'mt-10')),
    );
    final wBadge = tester.widget<WBadge>(find.byType(WBadge));
    expect(wBadge.className, contains('bg-primary'));
    expect(wBadge.className, contains('mt-10'));
  });
}
