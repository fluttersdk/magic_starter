import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
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

  /// Mounts [widget] on a surface of [size] logical pixels. Both
  /// `physicalSize` and `devicePixelRatio` are set, since setting only the
  /// first lays the tree out at the wrong logical width.
  Future<void> pumpAt(WidgetTester tester, Size size, Widget widget) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = size * 3.0;
    addTearDown(tester.view.reset);

    // `pump`, not `pumpAndSettle`: a loading button spins forever.
    await tester.pumpWidget(wrap(Center(child: widget)));
    await tester.pump();
  }

  const phone = Size(390, 844);
  const desktop = Size(1280, 800);

  // ---------------------------------------------------------------------------
  // Recipe variant-class assertions (TDD red: these must fail before impl)
  // ---------------------------------------------------------------------------

  group('button recipe', () {
    final buttonRecipe = buildButtonRecipe(const MagicStarterButtonTheme());

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

  // ---------------------------------------------------------------------------
  // Tap target
  // ---------------------------------------------------------------------------

  group('Button tap target', () {
    Widget smallButton({
      VoidCallback? onPressed,
      bool isLoading = false,
      bool disabled = false,
      bool fullWidth = false,
    }) => MSButton(
      size: ButtonSize.sm,
      onPressed: onPressed,
      isLoading: isLoading,
      disabled: disabled,
      fullWidth: fullWidth,
      child: const WText('Save'),
    );

    testWidgets('sm meets the iOS tap target on a phone', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAt(tester, phone, smallButton(onPressed: () {}));

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a full-width sm meets the iOS tap target on a phone', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        phone,
        // A Column, because a stretched button fills a BOUNDED height.
        SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [smallButton(onPressed: () {}, fullWidth: true)],
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      expect(tester.getSize(find.byType(WButton)).width, 300);
      handle.dispose();
    });

    testWidgets('sm paints at the same size on a phone and on desktop', (
      tester,
    ) async {
      await pumpAt(tester, desktop, smallButton(onPressed: () {}));
      final desktopSize = tester.getSize(find.byType(WButton));

      await pumpAt(tester, phone, smallButton(onPressed: () {}));

      expect(tester.getSize(find.byType(WButton)), desktopSize);
      expect(desktopSize.height, lessThan(44));
    });

    testWidgets('a tap just outside the painted button presses it', (
      tester,
    ) async {
      var presses = 0;
      await pumpAt(tester, phone, smallButton(onPressed: () => presses++));

      final painted = tester.getRect(find.byType(WButton));
      await tester.tapAt(painted.topCenter - const Offset(0, 5));

      expect(presses, 1);
    });

    testWidgets('a tap on the painted button presses it once', (tester) async {
      var presses = 0;
      await pumpAt(tester, phone, smallButton(onPressed: () => presses++));

      await tester.tap(find.byType(WButton));

      expect(presses, 1);
    });

    testWidgets('a loading or disabled sm never fires from the extra area', (
      tester,
    ) async {
      var presses = 0;
      await pumpAt(
        tester,
        phone,
        smallButton(onPressed: () => presses++, isLoading: true),
      );
      var painted = tester.getRect(find.byType(WButton));
      await tester.tapAt(painted.topCenter - const Offset(0, 5));

      await pumpAt(
        tester,
        phone,
        smallButton(onPressed: () => presses++, disabled: true),
      );
      painted = tester.getRect(find.byType(WButton));
      await tester.tapAt(painted.topCenter - const Offset(0, 5));

      expect(presses, 0);
    });

    Widget sizedButton(
      ButtonSize size, {
      VoidCallback? onPressed,
      bool fullWidth = false,
    }) => MSButton(
      size: size,
      onPressed: onPressed,
      fullWidth: fullWidth,
      child: const WText('Save'),
    );

    for (final ButtonSize size in const [ButtonSize.md, ButtonSize.lg]) {
      testWidgets('${size.name} meets the iOS tap target on a phone', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpAt(tester, phone, sizedButton(size, onPressed: () {}));

        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('a full-width md meets the iOS tap target on a phone', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        phone,
        SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              sizedButton(ButtonSize.md, onPressed: () {}, fullWidth: true),
            ],
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      expect(tester.getSize(find.byType(WButton)).width, 300);
      handle.dispose();
    });

    testWidgets('md paints at the same size on a phone and on desktop', (
      tester,
    ) async {
      await pumpAt(
        tester,
        desktop,
        sizedButton(ButtonSize.md, onPressed: () {}),
      );
      final desktopSize = tester.getSize(find.byType(WButton));

      await pumpAt(tester, phone, sizedButton(ButtonSize.md, onPressed: () {}));

      expect(tester.getSize(find.byType(WButton)), desktopSize);
      expect(desktopSize.height, lessThan(44));
    });

    testWidgets('a tap just outside the painted md presses it', (tester) async {
      var presses = 0;
      await pumpAt(
        tester,
        phone,
        sizedButton(ButtonSize.md, onPressed: () => presses++),
      );

      final painted = tester.getRect(find.byType(WButton));
      await tester.tapAt(painted.topCenter - const Offset(0, 3));

      expect(presses, 1);
    });

    for (final ButtonSize size in const [ButtonSize.sm, ButtonSize.md]) {
      testWidgets('${size.name} has no hit area wrapper from lg up', (
        tester,
      ) async {
        await pumpAt(tester, desktop, sizedButton(size, onPressed: () {}));

        expect(
          tester.getSize(find.byType(MSButton)),
          tester.getSize(find.byType(WButton)),
        );
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Button theme
  // ---------------------------------------------------------------------------

  // The title-lg label of a host design system, 17 on 22 at weight 600, and the
  // 44 px it makes with 11 px above and below. Vertical padding and not
  // `min-h-11`: see the label-position group below.
  const standardSize =
      'px-5 py-[11px] text-[17px] leading-[22px] font-semibold';

  // One capsule for every intent and size, with the secondary border dropped.
  const capsule = MagicStarterButtonTheme(
    shapeClassName: 'rounded-full',
    smClassName: standardSize,
    mdClassName: standardSize,
    lgClassName: standardSize,
    secondaryBorderClassName: '',
  );

  /// The decoration Wind paints behind the label of the one [WButton] on screen.
  BoxDecoration paintedDecoration(WidgetTester tester) {
    return tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(WButton),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .first;
  }

  /// The vertical centre of the glyphs of [text], not of the box Flutter lays
  /// the paragraph in: under a minimum height the paragraph is stretched to
  /// fill it with its glyphs at the top, so the box centre would lie.
  double glyphCentre(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
    final box = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        )
        .first;

    return paragraph.localToGlobal(box.toRect().center).dy;
  }

  Widget labelled(
    ButtonSize size, {
    ButtonIntent intent = ButtonIntent.primary,
    VoidCallback? onPressed,
    bool fullWidth = false,
    String? className,
  }) => MSButton(
    size: size,
    intent: intent,
    onPressed: onPressed ?? () {},
    fullWidth: fullWidth,
    className: className,
    child: const WText('Save'),
  );

  group('button recipe from a theme', () {
    // The previous const recipe, copied verbatim and not derived from the
    // builder: a refactor that moved a token cannot move this with it.
    const legacyBase =
        'inline-flex items-center font-medium rounded-lg transition-colors '
        'disabled:opacity-50 disabled:cursor-not-allowed focus:outline-none '
        'focus:ring-2 focus:ring-offset-1';
    const legacyIntent = {
      'primary':
          'bg-primary text-on-primary hover:opacity-90 focus:ring-color-border',
      'secondary':
          'bg-surface-container-high text-fg border border-color-border '
          'hover:bg-surface-container-high hover:opacity-80',
      'ghost': 'bg-transparent text-fg hover:bg-surface-container-high',
      'destructive':
          'bg-destructive text-on-destructive hover:opacity-90 '
          'focus:ring-bg-destructive',
    };
    const legacySize = {
      'sm': 'px-3 py-1.5 text-sm',
      'md': 'px-4 py-2 text-sm',
      'lg': 'px-5 py-3 text-base',
    };

    for (final intent in ButtonIntent.values) {
      for (final size in ButtonSize.values) {
        test('the default theme emits the previous ${intent.name} ${size.name} '
            'className byte for byte', () {
          final recipe = buildButtonRecipe(const MagicStarterButtonTheme());

          expect(
            recipe(
              variants: {
                kButtonIntentAxis: intent.name,
                kButtonSizeAxis: size.name,
              },
            ),
            '$legacyBase ${legacyIntent[intent.name]} ${legacySize[size.name]}',
          );
        });
      }
    }

    test('the shape replaces rounded-lg where it sat in the base', () {
      final recipe = buildButtonRecipe(
        const MagicStarterButtonTheme(shapeClassName: 'rounded-full'),
      );
      final cls = recipe();

      expect(cls, contains('font-medium rounded-full transition-colors'));
      expect(cls, isNot(contains('rounded-lg')));
    });

    test('each size class lands in its own slot and no other', () {
      final recipe = buildButtonRecipe(
        const MagicStarterButtonTheme(
          smClassName: 'sm-class',
          mdClassName: 'md-class',
          lgClassName: 'lg-class',
        ),
      );

      for (final size in ButtonSize.values) {
        final cls = recipe(variants: {kButtonSizeAxis: size.name});

        expect(cls, endsWith('${size.name}-class'));
        for (final other in ButtonSize.values.where((s) => s != size)) {
          expect(cls, isNot(contains('${other.name}-class')));
        }
      }
    });

    test('an empty secondary border leaves no token and no double space', () {
      final recipe = buildButtonRecipe(
        const MagicStarterButtonTheme(secondaryBorderClassName: ''),
      );
      final cls = recipe(variants: {kButtonIntentAxis: 'secondary'});

      expect(cls.split(' '), isNot(contains('border')));
      expect(cls, isNot(contains('border-color-border')));
      expect(cls, isNot(contains('  ')));
      expect(cls, contains('bg-surface-container-high text-fg hover:'));
    });

    test('the secondary border only exists on the secondary intent', () {
      final recipe = buildButtonRecipe(
        const MagicStarterButtonTheme(secondaryBorderClassName: 'border-2'),
      );

      expect(
        recipe(variants: {kButtonIntentAxis: 'secondary'}),
        contains('border-2'),
      );
      for (final intent in ['primary', 'ghost', 'destructive']) {
        expect(
          recipe(variants: {kButtonIntentAxis: intent}),
          isNot(contains('border-2')),
        );
      }
    });
  });

  group('button default theme', () {
    // The sizes below are line boxes, not glyph metrics (Wind sets the line
    // height from the `text-*` token), so they hold with the test font. They are
    // the numbers the previous recipe painted, measured before the change.
    const painted = {
      ButtonSize.sm: 32.0,
      ButtonSize.md: 36.0,
      ButtonSize.lg: 47.0,
    };

    for (final size in ButtonSize.values) {
      testWidgets('${size.name} paints ${painted[size]} px tall from lg up', (
        tester,
      ) async {
        await pumpAt(tester, desktop, labelled(size));

        expect(tester.getSize(find.byType(WButton)).height, painted[size]);
        expect(tester.getSize(find.byType(MSButton)).height, painted[size]);
      });
    }

    testWidgets('secondary paints its border, two pixels taller than primary', (
      tester,
    ) async {
      await pumpAt(
        tester,
        desktop,
        labelled(ButtonSize.md, intent: ButtonIntent.secondary),
      );

      expect(tester.getSize(find.byType(WButton)).height, 38);
      expect(paintedDecoration(tester).border, isNotNull);
    });

    testWidgets('the corners are the large radius', (tester) async {
      await pumpAt(tester, desktop, labelled(ButtonSize.md));

      expect(paintedDecoration(tester).borderRadius, BorderRadius.circular(8));
    });

    for (final size in [ButtonSize.sm, ButtonSize.md]) {
      testWidgets('${size.name} keeps its painted size inside a 44 px hit area '
          'on a phone', (tester) async {
        await pumpAt(tester, phone, labelled(size));

        expect(tester.getSize(find.byType(WButton)).height, painted[size]);
        expect(tester.getSize(find.byType(MSButton)).height, 44);
      });
    }

    testWidgets('lg is wider than the hit area and is not wrapped taller', (
      tester,
    ) async {
      await pumpAt(tester, phone, labelled(ButtonSize.lg));

      expect(tester.getSize(find.byType(MSButton)).height, 47);
    });
  });

  group('button host theme', () {
    for (final intent in ButtonIntent.values) {
      for (final size in ButtonSize.values) {
        testWidgets('${intent.name} ${size.name} is a 44 px capsule from lg up '
            'and keeps its intent colour', (tester) async {
          MagicStarter.useButtonTheme(capsule);
          await pumpAt(tester, desktop, labelled(size, intent: intent));

          final button = tester.widget<WButton>(find.byType(WButton));
          final decoration = paintedDecoration(tester);
          final style = tester
              .renderObject<RenderParagraph>(find.text('Save'))
              .text
              .style;

          expect(tester.getSize(find.byType(WButton)).height, 44);
          expect(decoration.borderRadius, BorderRadius.circular(9999));
          expect(decoration.border, isNull);
          expect(button.className, isNot(contains('rounded-lg')));
          expect(button.className, contains(standardSize));
          expect(style?.fontSize, 17);
          expect(style?.fontWeight, FontWeight.w600);
          expect(
            button.className,
            contains(switch (intent) {
              ButtonIntent.primary => 'bg-primary',
              ButtonIntent.secondary => 'bg-surface-container-high',
              ButtonIntent.ghost => 'bg-transparent',
              ButtonIntent.destructive => 'bg-destructive',
            }),
          );
        });

        testWidgets('${intent.name} ${size.name} adds nothing around a 44 px '
            'button on a phone', (tester) async {
          MagicStarter.useButtonTheme(capsule);
          await pumpAt(tester, phone, labelled(size, intent: intent));

          expect(tester.getSize(find.byType(WButton)), const Size(109, 44));
          expect(
            tester.getSize(find.byType(MSButton)),
            tester.getSize(find.byType(WButton)),
          );
        });
      }
    }

    testWidgets(
      'min-h-11 with a capsule makes md 44 px tall and fully rounded',
      (tester) async {
        MagicStarter.useButtonTheme(
          const MagicStarterButtonTheme(
            shapeClassName: 'rounded-full',
            mdClassName:
                'min-h-11 px-5 text-[17px] leading-[22px] font-semibold',
          ),
        );
        await pumpAt(tester, desktop, labelled(ButtonSize.md));

        expect(tester.getSize(find.byType(WButton)).height, 44);
        expect(
          paintedDecoration(tester).borderRadius,
          BorderRadius.circular(9999),
        );
      },
    );

    testWidgets('a theme leaves the sizes it does not name at their defaults', (
      tester,
    ) async {
      MagicStarter.useButtonTheme(
        const MagicStarterButtonTheme(mdClassName: standardSize),
      );
      await pumpAt(tester, desktop, labelled(ButtonSize.sm));

      expect(tester.getSize(find.byType(WButton)).height, 32);
    });

    testWidgets('a secondary that keeps its border is two pixels taller', (
      tester,
    ) async {
      MagicStarter.useButtonTheme(
        const MagicStarterButtonTheme(
          shapeClassName: 'rounded-full',
          mdClassName: standardSize,
        ),
      );
      await pumpAt(
        tester,
        desktop,
        labelled(ButtonSize.md, intent: ButtonIntent.secondary),
      );

      expect(tester.getSize(find.byType(WButton)).height, 46);
      expect(paintedDecoration(tester).border, isNotNull);
    });

    testWidgets('a caller className still wins over the theme', (tester) async {
      // The auth views hand their form theme's button classNames to MSButton,
      // so those win over this theme wherever they name the same family.
      MagicStarter.useButtonTheme(capsule);
      await pumpAt(
        tester,
        desktop,
        labelled(ButtonSize.md, className: 'rounded-lg'),
      );

      expect(paintedDecoration(tester).borderRadius, BorderRadius.circular(8));
    });
  });

  group('button host theme label position', () {
    testWidgets('vertical padding centres the label in the 44 px button', (
      tester,
    ) async {
      MagicStarter.useButtonTheme(capsule);
      await pumpAt(tester, desktop, labelled(ButtonSize.md));

      expect(
        glyphCentre(tester, 'Save'),
        closeTo(tester.getCenter(find.byType(WButton)).dy, 1),
      );
    });

    testWidgets('min-h-11 alone measures 44 but leaves the label at the top', (
      tester,
    ) async {
      // Pinned because it decides which form the docs recommend. WButton gives
      // its box a minimum height and no alignment (`items-center` is ignored
      // for the one child, and `justify-center` would also stretch the button
      // to fill its parent), so the paragraph is stretched to 44 with its glyphs
      // at the top. If Wind starts centring, this fails and the caveat in
      // doc/guides/wind-theme-adoption.md goes with it.
      MagicStarter.useButtonTheme(
        const MagicStarterButtonTheme(
          mdClassName: 'min-h-11 px-5 text-[17px] leading-[22px] font-semibold',
        ),
      );
      await pumpAt(tester, desktop, labelled(ButtonSize.md));

      expect(tester.getSize(find.byType(WButton)).height, 44);
      expect(
        glyphCentre(tester, 'Save'),
        lessThan(tester.getCenter(find.byType(WButton)).dy - 5),
      );
    });
  });

  group('button host theme full width', () {
    for (final entry in {'phone': phone, 'desktop': desktop}.entries) {
      testWidgets('fills a SizedBox parent and stays 44 px on ${entry.key}', (
        tester,
      ) async {
        MagicStarter.useButtonTheme(capsule);
        await pumpAt(
          tester,
          entry.value,
          SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [labelled(ButtonSize.md, fullWidth: true)],
            ),
          ),
        );

        expect(tester.getSize(find.byType(WButton)), const Size(300, 44));
        expect(tester.getSize(find.byType(MSButton)), const Size(300, 44));
      });

      testWidgets(
        'fills a w-full Wind column and stays 44 px on ${entry.key}',
        (tester) async {
          MagicStarter.useButtonTheme(capsule);
          await pumpAt(
            tester,
            entry.value,
            SizedBox(
              width: 300,
              child: WDiv(
                className: 'w-full flex flex-col gap-4',
                children: [
                  labelled(ButtonSize.md, fullWidth: true),
                  labelled(
                    ButtonSize.md,
                    fullWidth: true,
                    intent: ButtonIntent.secondary,
                  ),
                ],
              ),
            ),
          );

          for (final button in tester.widgetList(find.byType(WButton))) {
            final size = tester.getSize(find.byWidget(button));

            expect(size, const Size(300, 44));
          }
        },
      );
    }

    testWidgets('a full-width capsule meets the iOS tap target on a phone', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      MagicStarter.useButtonTheme(capsule);
      await pumpAt(
        tester,
        phone,
        SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [labelled(ButtonSize.md, fullWidth: true)],
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a 44 px button gets no hit area beyond its own edge', (
      tester,
    ) async {
      var presses = 0;
      MagicStarter.useButtonTheme(capsule);
      await pumpAt(
        tester,
        phone,
        labelled(ButtonSize.md, onPressed: () => presses++),
      );

      final painted = tester.getRect(find.byType(WButton));
      await tester.tapAt(painted.topCenter - const Offset(0, 3));
      expect(presses, 0);

      await tester.tap(find.byType(WButton));
      expect(presses, 1);
    });
  });

  group('danger outline className', () {
    // The real alias map, so `text-fg` and `border-color-border` resolve the
    // way they do in an app and the danger pair has something to override.
    // `aliases` lets a host define its own `text-destructive`; `className`
    // replaces the resolved danger class.
    Future<Color?> labelColour(
      WidgetTester tester, {
      Map<String, String> aliases = MagicStarterTokens.defaultAliases,
      String? className,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(aliases: aliases),
            child: Scaffold(
              body: Builder(
                builder: (context) => MSButton(
                  intent: ButtonIntent.secondary,
                  className: className ?? buttonDangerOutlineClassName(context),
                  onPressed: () {},
                  child: const WText('Remove'),
                ),
              ),
            ),
          ),
        ),
      );

      return tester
          .renderObject<RenderParagraph>(find.text('Remove'))
          .text
          .style
          ?.color;
    }

    testWidgets('paints the label red under the stock aliases', (tester) async {
      expect(await labelColour(tester), WindThemeData().getColor('red', 600));
    });

    testWidgets('paints the label in a host text-destructive', (tester) async {
      expect(
        await labelColour(
          tester,
          aliases: {
            ...MagicStarterTokens.defaultAliases,
            'text-destructive': 'text-[#DF202E] dark:text-[#FF645F]',
          },
        ),
        const Color(0xFFDF202E),
      );
    });

    testWidgets('`text-destructive` is no alias and leaves the label neutral', (
      tester,
    ) async {
      // Pins the gap buttonDangerOutlineClassName(context) resolves around: if
      // the alias contract ever ships a destructive text role, this fails and
      // the function can drop its fallback.
      expect(
        await labelColour(tester, className: 'text-destructive'),
        isNot(WindThemeData().getColor('red', 600)),
      );
    });
  });
}
