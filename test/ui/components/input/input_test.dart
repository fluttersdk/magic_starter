import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/input/input.preview.dart';

import '../field_theme_fixture.dart';

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
  // Recipe variant-class assertions
  // ---------------------------------------------------------------------------

  group('input recipe', () {
    final inputRecipe = buildInputRecipe(const MagicStarterFieldTheme());

    test('default state emits bg-surface-container-high token', () {
      final cls = inputRecipe(variants: {'state': InputState.normal.name});
      expect(cls, contains('bg-surface-container-high'));
    });

    test('error state emits border-destructive or similar error token', () {
      final cls = inputRecipe(variants: {'state': InputState.error.name});
      // Error state should apply error styling class
      expect(cls, contains('border'));
    });

    test('default variant produces normal state when nothing is passed', () {
      final cls = inputRecipe();
      expect(cls, contains('bg-surface-container-high'));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Input renders a WInput or WFormInput widget', (tester) async {
    await tester.pumpWidget(wrap(const MSInput(placeholder: 'Enter text')));
    // Input wraps WInput
    expect(find.byType(WInput), findsOneWidget);
  });

  testWidgets('Input applies bg-surface-container-high in normal state', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSInput(placeholder: 'Enter text')));
    final widget = tester.widget<WInput>(find.byType(WInput));
    expect(widget.className, contains('bg-surface-container-high'));
  });

  testWidgets('Input preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const InputPreview()));
    await tester.pump();
    expect(find.byType(InputPreview), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Input appends caller className onto the recipe base', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MSInput(placeholder: 'x', className: 'mt-10')),
    );
    final widget = tester.widget<WInput>(find.byType(WInput));
    expect(widget.className, contains('bg-surface-container-high'));
    expect(widget.className, contains('mt-10'));
  });

  // ---------------------------------------------------------------------------
  // fullWidth prop (MS-2)
  // ---------------------------------------------------------------------------

  testWidgets(
    'Input(fullWidth: true) wraps the WInput in a SizedBox(width: infinity) '
    'and keeps intent styling',
    (tester) async {
      await tester.pumpWidget(
        wrap(const MSInput(fullWidth: true, placeholder: 'Enter text')),
      );

      final fullWidthWrapper = find.ancestor(
        of: find.byType(WInput),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == double.infinity,
        ),
      );
      expect(fullWidthWrapper, findsOneWidget);

      final widget = tester.widget<WInput>(find.byType(WInput));
      expect(widget.className, contains('bg-surface-container-high'));
    },
  );

  testWidgets('Input fullWidth defaults to false (no SizedBox wrapper)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSInput(placeholder: 'Hi')));

    final fullWidthWrapper = find.ancestor(
      of: find.byType(WInput),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == double.infinity,
      ),
    );
    expect(fullWidthWrapper, findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Single-line height
  // ---------------------------------------------------------------------------

  testWidgets('Input measures at least 40 logical px tall', (tester) async {
    await tester.pumpWidget(wrap(const MSInput(placeholder: 'Enter text')));

    expect(
      tester.getSize(find.byType(MSInput)).height,
      greaterThanOrEqualTo(40),
    );
  });

  testWidgets('Input insets its text 12 logical px from the left edge', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSInput(placeholder: 'Enter text')));

    // WInput drops its 12px default content padding as soon as the className
    // sets any padding, so the recipe's `py-*` must carry its own `px-*`.
    final double inset =
        tester.getTopLeft(find.text('Enter text')).dx -
        tester.getTopLeft(find.byType(WInput)).dx;
    expect(inset, 12);
  });

  // ---------------------------------------------------------------------------
  // Touch target: 44 px below lg, unchanged from lg up
  // ---------------------------------------------------------------------------

  group('Input touch target', () {
    const phone = Size(390, 844);
    const desktop = Size(1280, 800);

    /// Both `physicalSize` and `devicePixelRatio` are set, since setting only
    /// the first lays the tree out at the wrong logical width.
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = size * 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(const Center(child: MSInput(placeholder: 'Enter text'))),
      );
      await tester.pump();
    }

    testWidgets('paints at least 44 px tall on a phone', (tester) async {
      await pumpAt(tester, phone);

      expect(
        tester.getSize(find.byType(WInput)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('keeps its text vertically centred in the 44 px box', (
      tester,
    ) async {
      await pumpAt(tester, phone);

      expect(
        tester.getCenter(find.text('Enter text')).dy,
        closeTo(tester.getCenter(find.byType(WInput)).dy, 1),
      );
    });

    testWidgets('meets the iOS tap target on a phone', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAt(tester, phone);

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('keeps its height from lg up', (tester) async {
      await pumpAt(tester, desktop);

      expect(tester.getSize(find.byType(WInput)).height, 40);
    });
  });

  // ---------------------------------------------------------------------------
  // Field theme
  // ---------------------------------------------------------------------------

  // The recipe before the size became a theme field, copied verbatim and not
  // derived from the builder: a refactor that moved a token cannot move this
  // with it.
  const legacyBase =
      'rounded-lg border px-3 py-3 lg:py-2.5 text-fg text-sm leading-5 '
      'focus:ring-2 disabled:opacity-50 disabled:cursor-not-allowed';
  const legacyState = {
    'normal':
        'bg-surface-container-high border-color-border '
        'focus:border-color-border focus:ring-bg-primary',
    'error':
        'bg-surface-container-high border-bg-destructive '
        'focus:ring-bg-destructive',
  };

  // The previous recipe with `text-fg` moved ahead of the size, so the size is
  // one run of tokens a theme can replace: `text-fg` sat between the padding
  // and the type, and a host's string has no business restating the colour.
  const defaultBase =
      'rounded-lg border px-3 text-fg py-3 lg:py-2.5 text-sm leading-5 '
      'focus:ring-2 disabled:opacity-50 disabled:cursor-not-allowed';

  group('input recipe from a theme', () {
    for (final state in InputState.values) {
      test('the default theme emits the previous ${state.name} className '
          'with only text-fg moved', () {
        final cls = buildInputRecipe(const MagicStarterFieldTheme())(
          variants: {kInputStateAxis: state.name},
        );

        expect(cls, '$defaultBase ${legacyState[state.name]}');
        expect(
          cls.split(' ')..sort(),
          '$legacyBase ${legacyState[state.name]}'.split(' ')..sort(),
        );
      });

      testWidgets(
        'the moved text-fg leaves the ${state.name} style as it was',
        (tester) async {
          for (final brightness in Brightness.values) {
            late BuildContext context;
            await tester.pumpWidget(
              MaterialApp(
                home: WindTheme(
                  data: WindThemeData(
                    brightness: brightness,
                    syncWithSystem: false,
                  ),
                  child: Builder(
                    builder: (inner) {
                      context = inner;
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            );

            expect(
              WindParser.parse(
                '$defaultBase ${legacyState[state.name]}',
                context,
              ),
              WindParser.parse(
                '$legacyBase ${legacyState[state.name]}',
                context,
              ),
            );
          }
        },
      );
    }

    test('the size replaces the padding and type run and nothing else', () {
      final cls = buildInputRecipe(hostFieldTheme)();

      expect(
        cls,
        startsWith(
          'rounded-lg border px-3 text-fg py-[11px] text-[17px] '
          'leading-[22px] focus:ring-2 disabled:opacity-50',
        ),
      );
      for (final gone in ['py-3', 'lg:py-2.5', 'text-sm', 'leading-5']) {
        expect(cls.split(' '), isNot(contains(gone)));
      }
    });
  });

  group('input default theme', () {
    testWidgets('paints 44 px below lg and 40 px from lg up, 14 on 20', (
      tester,
    ) async {
      await pumpControlAt(
        tester,
        kPhone,
        const MSInput(placeholder: 'Enter text'),
      );
      expect(tester.getSize(find.byType(WInput)).height, 44);
      expect(paintedStyle(tester, 'Enter text')?.fontSize, 14);

      await pumpControlAt(
        tester,
        kDesktop,
        const MSInput(placeholder: 'Enter text'),
      );
      expect(tester.getSize(find.byType(WInput)).height, 40);
    });
  });

  group('input host theme', () {
    for (final brightness in Brightness.values) {
      for (final entry in {'phone': kPhone, 'desktop': kDesktop}.entries) {
        final label = '${brightness.name} ${entry.key}';

        testWidgets('is 44 px tall with a 17 on 22 placeholder, $label', (
          tester,
        ) async {
          MagicStarter.useFieldTheme(hostFieldTheme);
          await pumpControlAt(
            tester,
            entry.value,
            const MSInput(placeholder: 'Enter text'),
            brightness: brightness,
          );

          final style = paintedStyle(tester, 'Enter text');

          expect(tester.getSize(find.byType(WInput)).height, 44);
          expect(style?.fontSize, 17);
          expect(lineHeightOf(tester, 'Enter text'), closeTo(22, 0.01));
        });

        testWidgets('types the value at 17 on 22 and centres it, $label', (
          tester,
        ) async {
          MagicStarter.useFieldTheme(hostFieldTheme);
          await pumpControlAt(
            tester,
            entry.value,
            const MSInput(value: 'Typed', placeholder: 'Enter text'),
            brightness: brightness,
          );

          final style = tester.widget<EditableText>(find.byType(EditableText));

          expect(tester.getSize(find.byType(WInput)).height, 44);
          expect(style.style.fontSize, 17);
          expect(
            style.style.fontSize! * style.style.height!,
            closeTo(22, 0.01),
          );
          // The editable's own box is the one 22 px line the value is painted
          // in. Its glyph boxes are not compared: they follow the font's
          // ascent and descent, which sit off the middle of a line in the test
          // font whatever the theme.
          expect(tester.getSize(find.byType(EditableText)).height, 22);
          expect(
            tester.getCenter(find.byType(EditableText)).dy,
            closeTo(tester.getCenter(find.byType(WInput)).dy, 1),
          );
        });

        testWidgets('centres the placeholder in the box, $label', (
          tester,
        ) async {
          MagicStarter.useFieldTheme(hostFieldTheme);
          await pumpControlAt(
            tester,
            entry.value,
            const MSInput(placeholder: 'Enter text'),
            brightness: brightness,
          );

          expect(
            glyphCentre(tester, 'Enter text'),
            closeTo(tester.getCenter(find.byType(WInput)).dy, 1),
          );
        });
      }
    }

    testWidgets('keeps the 12 px inset the recipe sets beside the size', (
      tester,
    ) async {
      MagicStarter.useFieldTheme(hostFieldTheme);
      await pumpControlAt(
        tester,
        kPhone,
        const MSInput(placeholder: 'Enter text'),
      );

      expect(
        tester.getTopLeft(find.text('Enter text')).dx -
            tester.getTopLeft(find.byType(WInput)).dx,
        12,
      );
    });

    testWidgets('py-2.5 around a 22 px line is 42, as the border adds nothing', (
      tester,
    ) async {
      // Pinned because it decides which padding the docs recommend. WInput
      // paints its border in a DecoratedBox inside the padding, so unlike a
      // select trigger (a Wind box, where the border adds to the size) the two
      // border pixels are not on top of 10 + 22 + 10. If Wind starts insetting
      // the child, this fails and the docs go with it.
      MagicStarter.useFieldTheme(
        const MagicStarterFieldTheme(
          inputSizeClassName: 'py-2.5 text-[17px] leading-[22px]',
        ),
      );
      await pumpControlAt(
        tester,
        kPhone,
        const MSInput(placeholder: 'Enter text'),
      );

      expect(tester.getSize(find.byType(WInput)).height, 42);
    });

    testWidgets('a caller className still wins over the theme', (tester) async {
      MagicStarter.useFieldTheme(hostFieldTheme);
      await pumpControlAt(
        tester,
        kPhone,
        const MSInput(placeholder: 'Enter text', className: 'py-3 text-sm'),
      );

      expect(tester.getSize(find.byType(WInput)).height, 12 + 22 + 12);
      expect(paintedStyle(tester, 'Enter text')?.fontSize, 14);
    });

    testWidgets('useWindTheme after useFieldTheme puts the defaults back', (
      tester,
    ) async {
      MagicStarter.useFieldTheme(hostFieldTheme);
      MagicStarter.useWindTheme(WindThemeData());
      await pumpControlAt(
        tester,
        kDesktop,
        const MSInput(placeholder: 'Enter text'),
      );

      expect(tester.getSize(find.byType(WInput)).height, 40);
    });

    testWidgets('useFieldTheme after useWindTheme keeps the host standard', (
      tester,
    ) async {
      MagicStarter.useWindTheme(WindThemeData());
      MagicStarter.useFieldTheme(hostFieldTheme);
      await pumpControlAt(
        tester,
        kDesktop,
        const MSInput(placeholder: 'Enter text'),
      );

      expect(tester.getSize(find.byType(WInput)).height, 44);
    });
  });
}
