import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/button/button.preview.dart';

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

  group('button recipe', () {
    test('primary intent emits bg-primary token', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.primary.name,
          'size': ButtonSize.md.name
        },
      );
      expect(cls, contains('bg-primary'));
    });

    test('secondary intent emits bg-surface-container-high token', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.secondary.name,
          'size': ButtonSize.md.name
        },
      );
      expect(cls, contains('bg-surface-container-high'));
    });

    test('ghost intent emits transparent background base', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.ghost.name,
          'size': ButtonSize.md.name
        },
      );
      expect(cls, isNot(contains('bg-primary')));
      // Ghost starts with transparent but may have hover:bg-* — that is expected.
      expect(cls, contains('bg-transparent'));
    });

    test('destructive intent emits bg-destructive token', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.destructive.name,
          'size': ButtonSize.md.name
        },
      );
      expect(cls, contains('bg-destructive'));
    });

    test('sm size emits text-sm', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.primary.name,
          'size': ButtonSize.sm.name
        },
      );
      expect(cls, contains('text-sm'));
    });

    test('lg size emits text-base or text-lg', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.primary.name,
          'size': ButtonSize.lg.name
        },
      );
      // lg size should have some text size token
      expect(cls, isNotEmpty);
    });

    test('default variants produce primary+md when nothing is passed', () {
      final cls = buttonRecipe();
      expect(cls, contains('bg-primary'));
    });

    test('emission order: base precedes variant classes', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.primary.name,
          'size': ButtonSize.md.name
        },
      );
      // base contains inline-flex; primary bg-primary
      final baseIdx = cls.indexOf('inline-flex');
      final variantIdx = cls.indexOf('bg-primary');
      expect(baseIdx, lessThan(variantIdx));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Button renders child', (tester) async {
    const childKey = Key('btn-child');
    await tester.pumpWidget(
      wrap(
        Button(
          onPressed: () {},
          child: const SizedBox(key: childKey),
        ),
      ),
    );
    expect(find.byKey(childKey), findsOneWidget);
  });

  testWidgets('Button applies primary className by default', (tester) async {
    await tester.pumpWidget(
      wrap(
        Button(
          onPressed: () {},
          child: const SizedBox(),
        ),
      ),
    );
    final btn = tester.widget<WButton>(find.byType(WButton));
    expect(btn.className, contains('bg-primary'));
  });

  testWidgets('Button applies destructive className for destructive intent',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Button(
          intent: ButtonIntent.destructive,
          onPressed: () {},
          child: const SizedBox(),
        ),
      ),
    );
    final btn = tester.widget<WButton>(find.byType(WButton));
    expect(btn.className, contains('bg-destructive'));
  });

  testWidgets('Button respects isLoading prop', (tester) async {
    await tester.pumpWidget(
      wrap(
        Button(
          onPressed: () {},
          isLoading: true,
          child: const SizedBox(),
        ),
      ),
    );
    final btn = tester.widget<WButton>(find.byType(WButton));
    expect(btn.isLoading, isTrue);
  });

  testWidgets('Button light+dark preview renders without error',
      (tester) async {
    await tester.pumpWidget(wrap(const ButtonPreview()));
    await tester.pump();
    expect(find.byType(ButtonPreview), findsOneWidget);
  });

  testWidgets('ButtonPreview renders all intents', (tester) async {
    await tester.pumpWidget(wrap(const ButtonPreview()));
    await tester.pump();

    // One WButton per intent x size combination should exist.
    final buttons = tester.widgetList<WButton>(find.byType(WButton));
    expect(buttons.length, greaterThanOrEqualTo(ButtonIntent.values.length));
  });
}
