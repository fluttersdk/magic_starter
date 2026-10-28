import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../field_theme_fixture.dart';

/// Serves a catalogue whose default placeholder differs from the English
/// fallback, so a hard-coded string cannot pass for a translated one.
class _SelectLangLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async => {
    'common.select_option': 'Pick one',
  };
}

void main() {
  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Translator.instance.setLoader(_SelectLangLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
    Translator.reset();
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
  // Recipe slot-class assertions (TDD: write failing tests first)
  // ---------------------------------------------------------------------------

  group('select recipe', () {
    test('trigger slot contains bg-surface-container-high', () {
      final cls = selectRecipe();
      expect(cls['trigger'], contains('bg-surface-container-high'));
    });

    test('popup slot contains bg-surface', () {
      final cls = selectRecipe();
      expect(cls['popup'], contains('bg-surface'));
    });

    test('item slot is non-empty', () {
      final cls = selectRecipe();
      expect(cls['item'], isNotEmpty);
    });

    test('all three required slots are present', () {
      final cls = selectRecipe();
      expect(cls.keys, containsAll(['trigger', 'popup', 'item']));
    });

    test('trigger slot carries a focus ring with its dark pair', () {
      final trigger = selectRecipe()['trigger'];
      expect(trigger, contains('focus:ring-2'));
      expect(trigger, contains('focus:ring-primary-500'));
      expect(trigger, contains('dark:focus:ring-primary-400'));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget interaction tests
  // ---------------------------------------------------------------------------

  group('Select widget', () {
    testWidgets('renders and shows WSelect', (tester) async {
      await tester.pumpWidget(
        wrap(
          MSSelect<String>(
            value: null,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WSelect<String>), findsOneWidget);
    });

    testWidgets('calls onChange when option is selected', (tester) async {
      String? selected;
      await tester.pumpWidget(
        wrap(
          MSSelect<String>(
            value: null,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (v) => selected = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the trigger to open.
      await tester.tap(find.byType(WSelect<String>));
      await tester.pumpAndSettle();

      // Tap the option.
      await tester.tap(find.text('Option A'));
      await tester.pumpAndSettle();

      expect(selected, equals('a'));
    });

    testWidgets('shows the translated default when no placeholder is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MSSelect<String>(
            value: null,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('Select an option'), findsNothing);
    });

    testWidgets('names the trigger by the translated default with no value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          MSSelect<String>(
            value: null,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(WSelect<String>)).label,
        equals('Pick one'),
      );
      handle.dispose();
    });

    testWidgets('an explicit placeholder wins over the translated default', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MSSelect<String>(
            value: null,
            placeholder: 'Choose a role',
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose a role'), findsOneWidget);
      expect(find.text('Pick one'), findsNothing);
    });
  });

  testWidgets('MSSelect trigger measures at least 40 logical px tall', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MSSelect<String>(
          value: null,
          options: const [SelectOption(value: 'a', label: 'Option A')],
          onChange: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(WSelect<String>)).height,
      greaterThanOrEqualTo(40),
    );
  });

  // ---------------------------------------------------------------------------
  // Keyboard focus ring
  // ---------------------------------------------------------------------------

  group('Select keyboard focus', () {
    /// The ring is an outline wind paints in a foreground DecoratedBox, so the
    /// resolved colour is read off the border rather than the className string.
    Finder ringOutline() => find.descendant(
      of: find.byType(MSSelect<String>),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    );

    Widget select({bool disabled = false}) => MSSelect<String>(
      value: null,
      options: const [SelectOption(value: 'a', label: 'Option A')],
      onChange: (_) {},
      disabled: disabled,
    );

    testWidgets('paints no ring while the select is at rest', (tester) async {
      await tester.pumpWidget(wrap(select()));
      await tester.pumpAndSettle();

      expect(ringOutline(), findsNothing);
    });

    testWidgets('Tab onto the select paints the primary ring', (tester) async {
      await tester.pumpWidget(wrap(select()));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(ringOutline(), findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(ringOutline()).decoration
              as BoxDecoration;
      expect(
        (decoration.border! as Border).top.color,
        WindThemeData().getColor('primary', 500),
      );
      // Focus alone must not open the menu.
      expect(find.text('Option A'), findsNothing);
    });

    testWidgets('a disabled select is skipped by Tab and paints no ring', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(select(disabled: true)));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(ringOutline(), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Touch target: 44 px below lg, unchanged from lg up
  // ---------------------------------------------------------------------------

  group('Select touch target', () {
    const phone = Size(390, 844);
    const desktop = Size(1280, 800);

    /// Both `physicalSize` and `devicePixelRatio` are set, since setting only
    /// the first lays the tree out at the wrong logical width.
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = size * 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          Center(
            child: MSSelect<String>(
              value: null,
              options: const [SelectOption(value: 'a', label: 'Option A')],
              onChange: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('paints at least 44 px tall on a phone', (tester) async {
      await pumpAt(tester, phone);

      expect(
        tester.getSize(find.byType(WSelect<String>)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('keeps its value vertically centred in the 44 px box', (
      tester,
    ) async {
      await pumpAt(tester, phone);

      expect(
        tester.getCenter(find.text('Pick one')).dy,
        closeTo(tester.getCenter(find.byType(WSelect<String>)).dy, 1),
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

      expect(tester.getSize(find.byType(WSelect<String>)).height, 40);
    });
  });

  // ---------------------------------------------------------------------------
  // Field theme
  // ---------------------------------------------------------------------------

  /// An [MSSelect] with one option, `Option A`, for a host to size.
  Widget control({
    String? value,
    String? placeholder,
    Map<String, String>? classNames,
  }) {
    return MSSelect<String>(
      value: value,
      placeholder: placeholder,
      classNames: classNames,
      options: const [SelectOption(value: 'a', label: 'Option A')],
      onChange: (_) {},
    );
  }

  group('select recipe from a theme', () {
    // The trigger before its size became a theme field, copied verbatim and not
    // derived from the recipe: a refactor that moved a token cannot move this
    // with it.
    const legacyTrigger =
        'w-full px-3 py-[9px] min-h-11 lg:min-h-0 rounded-lg '
        'bg-surface-container-high border border-color-border text-fg flex '
        'items-center justify-between gap-2 focus:ring-2 '
        'focus:ring-primary-500 dark:focus:ring-primary-400';

    test('the default theme emits the previous trigger byte for byte', () {
      expect(selectRecipe()['trigger'], legacyTrigger);
      expect(
        selectRecipe(theme: const MagicStarterFieldTheme())['trigger'],
        legacyTrigger,
      );
    });

    test('the popup and the item slots do not read the theme', () {
      final themed = selectRecipe(theme: hostFieldTheme);
      final stock = selectRecipe();

      expect(themed['popup'], stock['popup']);
      expect(themed['item'], stock['item']);
    });

    test('the size replaces the padding and minimum height run only', () {
      final trigger = selectRecipe(theme: hostFieldTheme)['trigger']!;

      expect(
        trigger,
        startsWith('w-full px-3 py-2.5 text-[17px] leading-[22px] rounded-lg '),
      );
      for (final gone in ['py-[9px]', 'min-h-11', 'lg:min-h-0']) {
        expect(trigger.split(' '), isNot(contains(gone)));
      }
    });
  });

  group('select default theme', () {
    for (final entry in {
      'phone': (kPhone, 44.0),
      'desktop': (kDesktop, 40.0),
    }.entries) {
      testWidgets('paints ${entry.value.$2} px tall on a ${entry.key}', (
        tester,
      ) async {
        await pumpControlAt(tester, entry.value.$1, control());

        expect(
          tester.getSize(find.byType(WSelect<String>)).height,
          entry.value.$2,
        );
      });
    }
  });

  group('select host theme', () {
    for (final brightness in Brightness.values) {
      for (final entry in {'phone': kPhone, 'desktop': kDesktop}.entries) {
        final label = '${brightness.name} ${entry.key}';

        testWidgets('is 44 px tall with a 17 on 22 value, centred, $label', (
          tester,
        ) async {
          MagicStarter.useFieldTheme(hostFieldTheme);
          await pumpControlAt(
            tester,
            entry.value,
            control(value: 'a'),
            brightness: brightness,
          );

          final trigger = find.byType(WSelect<String>);

          expect(tester.getSize(trigger).height, 44);
          expect(paintedStyle(tester, 'Option A')?.fontSize, 17);
          expect(lineHeightOf(tester, 'Option A'), closeTo(22, 0.01));
          expect(
            glyphCentre(tester, 'Option A'),
            closeTo(tester.getCenter(trigger).dy, 1),
          );
        });

        testWidgets(
          'is 44 px tall with a 17 on 22 placeholder, centred, $label',
          (tester) async {
            MagicStarter.useFieldTheme(hostFieldTheme);
            await pumpControlAt(
              tester,
              entry.value,
              control(placeholder: 'Choose one'),
              brightness: brightness,
            );

            final trigger = find.byType(WSelect<String>);

            expect(tester.getSize(trigger).height, 44);
            expect(paintedStyle(tester, 'Choose one')?.fontSize, 17);
            expect(lineHeightOf(tester, 'Choose one'), closeTo(22, 0.01));
            expect(
              glyphCentre(tester, 'Choose one'),
              closeTo(tester.getCenter(trigger).dy, 1),
            );
          },
        );
      }
    }

    testWidgets('a caller trigger className still wins over the theme', (
      tester,
    ) async {
      MagicStarter.useFieldTheme(hostFieldTheme);
      await pumpControlAt(
        tester,
        kPhone,
        control(value: 'a', classNames: const {'trigger': 'py-4'}),
      );

      expect(
        tester.getSize(find.byType(WSelect<String>)).height,
        16 + 22 + 16 + 2,
      );
    });

    testWidgets('useWindTheme after useFieldTheme puts the defaults back', (
      tester,
    ) async {
      MagicStarter.useFieldTheme(hostFieldTheme);
      MagicStarter.useWindTheme(WindThemeData());
      await pumpControlAt(tester, kDesktop, control(value: 'a'));

      expect(tester.getSize(find.byType(WSelect<String>)).height, 40);
    });
  });
}
