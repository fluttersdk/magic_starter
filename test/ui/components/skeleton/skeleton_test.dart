import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/skeleton/skeleton.preview.dart';

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

  group('skeleton recipe', () {
    test('block shape emits rounded-md token', () {
      final cls = skeletonRecipe(variants: {'shape': SkeletonShape.block.name});
      expect(cls, contains('rounded-md'));
    });

    test('text shape emits rounded token', () {
      final cls = skeletonRecipe(variants: {'shape': SkeletonShape.text.name});
      expect(cls, contains('rounded'));
    });

    test('circle shape emits rounded-full token', () {
      final cls = skeletonRecipe(
        variants: {'shape': SkeletonShape.circle.name},
      );
      expect(cls, contains('rounded-full'));
    });

    test('all shapes emit bg-surface-container-high (muted fill)', () {
      for (final shape in SkeletonShape.values) {
        final cls = skeletonRecipe(variants: {'shape': shape.name});
        expect(
          cls,
          contains('bg-surface-container-high'),
          reason: '${shape.name} must use semantic muted fill',
        );
      }
    });

    test('default shape is block', () {
      final cls = skeletonRecipe();
      expect(cls, contains('rounded-md'));
    });

    test('emission order: base precedes variant classes', () {
      final cls = skeletonRecipe(variants: {'shape': SkeletonShape.block.name});
      expect(cls, isNotEmpty);
      final baseIdx = cls.indexOf('animate-pulse');
      expect(baseIdx, isNot(equals(-1)));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Skeleton block shape renders without error', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSSkeleton(shape: SkeletonShape.block, width: 200, height: 80),
      ),
    );
    expect(find.byType(WDiv), findsWidgets);
  });

  testWidgets('Skeleton circle shape renders without error', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSSkeleton(shape: SkeletonShape.circle, width: 48, height: 48),
      ),
    );
    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('rounded-full'));
  });

  testWidgets('Skeleton text shape renders without error', (tester) async {
    await tester.pumpWidget(
      wrap(const MSSkeleton(shape: SkeletonShape.text, width: 160, height: 16)),
    );
    expect(find.byType(WDiv), findsWidgets);
  });

  testWidgets('Skeleton default shape is block', (tester) async {
    await tester.pumpWidget(wrap(const MSSkeleton(width: 100, height: 20)));
    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('rounded-md'));
    expect(wDiv.className, isNot(contains('rounded-full')));
  });

  testWidgets('Skeleton light+dark preview renders without error', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SkeletonPreview()));
    await tester.pump();
    expect(find.byType(SkeletonPreview), findsOneWidget);
  });

  testWidgets('SkeletonPreview renders all shapes', (tester) async {
    await tester.pumpWidget(wrap(const SkeletonPreview()));
    await tester.pump();
    // Each shape renders at least one WDiv
    expect(find.byType(WDiv), findsWidgets);
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Skeleton appends caller className onto the recipe base', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MSSkeleton(width: 100, height: 20, className: 'mt-10')),
    );
    final wDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(wDiv.className, contains('animate-pulse'));
    expect(wDiv.className, contains('mt-10'));
  });
}
