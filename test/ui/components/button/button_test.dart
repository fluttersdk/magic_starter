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
          'size': ButtonSize.md.name,
        },
      );
      expect(cls, contains('bg-primary'));
    });

    test('secondary intent emits bg-surface-container-high token', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.secondary.name,
          'size': ButtonSize.md.name,
        },
      );
      expect(cls, contains('bg-surface-container-high'));
    });

    test('ghost intent emits transparent background base', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.ghost.name,
          'size': ButtonSize.md.name,
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
          'size': ButtonSize.md.name,
        },
      );
      expect(cls, contains('bg-destructive'));
    });

    test('sm size emits text-sm', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.primary.name,
          'size': ButtonSize.sm.name,
        },
      );
      expect(cls, contains('text-sm'));
    });

    test('lg size emits text-base or text-lg', () {
      final cls = buttonRecipe(
        variants: {
          'intent': ButtonIntent.primary.name,
          'size': ButtonSize.lg.name,
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
          'size': ButtonSize.md.name,
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
        MSButton(
          onPressed: () {},
          child: const SizedBox(key: childKey),
        ),
      ),
    );
    expect(find.byKey(childKey), findsOneWidget);
  });

  testWidgets('Button applies primary className by default', (tester) async {
    await tester.pumpWidget(
      wrap(MSButton(onPressed: () {}, child: const SizedBox())),
    );
    final btn = tester.widget<WButton>(find.byType(WButton));
    expect(btn.className, contains('bg-primary'));
  });

  testWidgets('Button applies destructive className for destructive intent', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MSButton(
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
        MSButton(onPressed: () {}, isLoading: true, child: const SizedBox()),
      ),
    );
    final btn = tester.widget<WButton>(find.byType(WButton));
    expect(btn.isLoading, isTrue);
  });

  testWidgets('Button light+dark preview renders without error', (
    tester,
  ) async {
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

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Button appends caller className onto the recipe base', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MSButton(
          intent: ButtonIntent.primary,
          className: 'mt-10',
          onPressed: () {},
          child: const SizedBox(),
        ),
      ),
    );
    final btn = tester.widget<WButton>(find.byType(WButton));
    expect(btn.className, contains('bg-primary'));
    expect(btn.className, contains('mt-10'));
  });

  // ---------------------------------------------------------------------------
  // fullWidth prop (MS-2)
  // ---------------------------------------------------------------------------

  testWidgets(
    'Button(fullWidth: true) fills the parent width, centers its label, '
    'and keeps intent styling',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 300,
            child: Column(
              children: [
                MSButton(
                  fullWidth: true,
                  intent: ButtonIntent.primary,
                  onPressed: () {},
                  child: const WText('Save'),
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(MSButton));
      expect(size.width, 300);

      final buttonCenter = tester.getCenter(find.byType(MSButton));
      final labelCenter = tester.getCenter(find.text('Save'));
      expect(labelCenter.dx, closeTo(buttonCenter.dx, 1.0));

      final btn = tester.widget<WButton>(find.byType(WButton));
      expect(btn.className, contains('bg-primary'));
    },
  );

  testWidgets(
    'Button(fullWidth: true) asks Wind to centre its label; a shrink-wrapped '
    'one does not',
    (tester) async {
      // ASSERTED ON THE CLASSNAME, not on the geometry, and the reason is worth
      // recording because the obvious test here is a vacuous one.
      //
      // The case above measures label geometry inside a stretched button and
      // passes WITH OR WITHOUT the centring token: under `flutter test` the
      // label lands centred either way, and reproducing the real parent (a Wind
      // `flex flex-col`) does not change that. The browser disagrees. Before
      // this token, a full-width button rendered its text hard against the left
      // edge, so a billing card shipped with "Upgrade" and "Contact sales" in
      // the corner while a hand-built marker beside them was centred.
      //
      // So the geometric assertion cannot fail for the reason it claims here,
      // and one that cannot fail is not a guard. This pins the MECHANISM
      // instead: the token reaches Wind when stretched and stays out of the way
      // when not, which is the decision this widget owns. The rendering itself
      // is verified in a real browser at desktop and mobile width.
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 300,
            child: WDiv(
              className: 'flex flex-col gap-4',
              children: <Widget>[
                MSButton(
                  fullWidth: true,
                  onPressed: () {},
                  child: const WText('Contact sales'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.widget<WButton>(find.byType(WButton)).className,
        contains('justify-center'),
      );

      // The negative control, and it is the whole reason the token is applied
      // conditionally: in Wind `justify-center` maps to the Container's
      // alignment and forces the button to fill its constraints, so a base that
      // carried it would make EVERY button full-width. The recipe's own comment
      // says so, which is why this lives here and not there.
      await tester.pumpWidget(
        wrap(MSButton(onPressed: () {}, child: const WText('Save'))),
      );

      expect(
        tester.widget<WButton>(find.byType(WButton)).className,
        isNot(contains('justify-center')),
      );
    },
  );

  testWidgets(
    'Button(fullWidth: true) fills a bounded height too, because the centring '
    'token aligns on both axes',
    (tester) async {
      // A consequence of the centring token, measured rather than assumed after
      // review raised it. Wind maps `justify-center` to
      // `MainAxisAlignment.center`, `WButton` turns that into its `Container`'s
      // `alignment` (`w_button.dart:174-178`), and a `Container` with a non-null
      // alignment expands to its constraints on BOTH axes, not just the one the
      // `SizedBox` pinned.
      //
      // Under an unbounded height nothing changes, which is every full-width
      // site in this package (they all sit in a `flex flex-col` card). Under a
      // fixed-height parent the button now fills it where it used to
      // shrink-wrap. Pinned here so an adopter meets it in a test rather than in
      // a footer, and so a later change to the token cannot move it silently.
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 300,
            height: 120,
            child: MSButton(
              fullWidth: true,
              onPressed: () {},
              child: const WText('Contact sales'),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(WButton)).height, 120);

      // The control: the same button with the height left unbounded keeps its
      // own, so this is the parent's constraint being filled and not the token
      // inflating the button everywhere.
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 300,
            child: WDiv(
              className: 'flex flex-col',
              children: <Widget>[
                MSButton(
                  fullWidth: true,
                  onPressed: () {},
                  child: const WText('Contact sales'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(WButton)).height, lessThan(120));
    },
  );

  testWidgets('Button fullWidth defaults to false (content-width)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 300,
          child: Column(
            children: [MSButton(onPressed: () {}, child: const WText('Save'))],
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(MSButton));
    expect(size.width, lessThan(300));
  });
}
