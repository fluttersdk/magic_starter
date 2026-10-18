import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Serves a catalogue whose default placeholder differs from the English
/// fallback, so a hard-coded string cannot pass for a translated one.
class _ComboboxLangLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async => {
    'common.search_options': 'Find one',
    'common.search_placeholder': 'Look up',
  };
}

void main() {
  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Translator.instance.setLoader(_ComboboxLangLoader());
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
  // Recipe slot-class assertions
  // ---------------------------------------------------------------------------

  group('combobox recipe', () {
    test('trigger slot contains bg-surface-container-high', () {
      final cls = comboboxRecipe();
      expect(cls['trigger'], contains('bg-surface-container-high'));
    });

    test('popup slot contains bg-surface', () {
      final cls = comboboxRecipe();
      expect(cls['popup'], contains('bg-surface'));
    });

    test('item slot is non-empty', () {
      final cls = comboboxRecipe();
      expect(cls['item'], isNotEmpty);
    });

    test('all three required slots are present', () {
      final cls = comboboxRecipe();
      expect(cls.keys, containsAll(['trigger', 'popup', 'item']));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget interaction tests
  // ---------------------------------------------------------------------------

  group('Combobox widget', () {
    testWidgets('renders WSelect with searchable=true', (tester) async {
      await tester.pumpWidget(
        wrap(
          MSCombobox<String>(
            value: null,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final select = tester.widget<WSelect<String>>(
        find.byType(WSelect<String>),
      );
      expect(select.searchable, isTrue);
    });

    testWidgets('shows the translated default when no placeholder is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MSCombobox<String>(
            value: null,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find one'), findsOneWidget);
      expect(find.text('Search options...'), findsNothing);
    });

    testWidgets('names the trigger by the translated default with no value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          MSCombobox<String>(
            value: null,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(WSelect<String>)).label,
        equals('Find one'),
      );
      handle.dispose();
    });
  });

  group('Combobox search placeholder', () {
    Future<void> openWith(
      WidgetTester tester, {
      String? searchPlaceholder,
    }) async {
      await tester.pumpWidget(
        wrap(
          MSCombobox<String>(
            value: null,
            searchPlaceholder: searchPlaceholder,
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(WSelect<String>));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the translated default in the search field', (
      tester,
    ) async {
      await openWith(tester);

      expect(find.text('Look up'), findsOneWidget);
      expect(find.text('Search...'), findsNothing);
    });

    testWidgets('an explicit searchPlaceholder wins over the translation', (
      tester,
    ) async {
      await openWith(tester, searchPlaceholder: 'Filter countries');

      expect(find.text('Filter countries'), findsOneWidget);
      expect(find.text('Look up'), findsNothing);
    });
  });

  testWidgets('MSCombobox trigger measures at least 40 logical px tall', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MSCombobox<String>(
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
  // Touch target: 44 px below lg, unchanged from lg up
  // ---------------------------------------------------------------------------

  group('Combobox touch target', () {
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
            child: MSCombobox<String>(
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
        tester.getCenter(find.text('Find one')).dy,
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
}
