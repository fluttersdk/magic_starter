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
}
