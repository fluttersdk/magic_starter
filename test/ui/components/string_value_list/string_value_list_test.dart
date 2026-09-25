import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

String _removeValueLabel(String value) => 'Remove $value';

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

  Widget wrap(Widget widget, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(
            brightness: brightness,
            aliases: MagicStarterTokens.defaultAliases,
          ),
          child: Scaffold(body: SingleChildScrollView(child: widget)),
        ),
      );

  Widget buildList({
    required List<String> value,
    required ValueChanged<List<String>> onChanged,
    StringValueListTone tone = StringValueListTone.neutral,
  }) => MSStringValueList(
    value: value,
    onChanged: onChanged,
    tone: tone,
    placeholder: 'Enter value',
    addLabel: 'Add value',
    removeValueLabel: _removeValueLabel,
  );

  // ---------------------------------------------------------------------------
  // Recipe token assertions
  // ---------------------------------------------------------------------------

  group('stringValueListRecipe', () {
    test('neutral chip sits on the surface-container-high token', () {
      final slots = stringValueListRecipe(
        variants: const {kStringValueListToneAxis: 'neutral'},
      );
      expect(slots['chip'], contains('bg-surface-container-high'));
    });

    test('warn chip uses the warning token pair', () {
      final slots = stringValueListRecipe(
        variants: const {kStringValueListToneAxis: 'warn'},
      );
      expect(slots['chip'], contains('bg-warning'));
    });

    test('critical chip uses the destructive-container token', () {
      final slots = stringValueListRecipe(
        variants: const {kStringValueListToneAxis: 'critical'},
      );
      expect(slots['chip'], contains('bg-destructive-container'));
    });
  });

  // ---------------------------------------------------------------------------
  // Commit: Enter / IME done
  // ---------------------------------------------------------------------------

  testWidgets('submitting text via the IME done action adds a chip', (
    tester,
  ) async {
    List<String> current = const [];
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => buildList(
            value: current,
            onChanged: (v) => setState(() => current = v),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(WInput), 'ok');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(current, ['ok']);
    expect(find.text('ok'), findsOneWidget);
  });

  // QA: typing `a`, Enter, `A`, Enter yields `['a']`.
  testWidgets(
    'typing a, Enter, A, Enter yields [a]: dedupe is case-insensitive',
    (tester) async {
      List<String> current = const [];
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => buildList(
              value: current,
              onChanged: (v) => setState(() => current = v),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(WInput), 'a');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      await tester.enterText(find.byType(WInput), 'A');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(current, ['a']);
    },
  );

  testWidgets('a stored value with padding is still a duplicate', (
    tester,
  ) async {
    List<String> padded = const [' ok '];
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => buildList(
            value: padded,
            onChanged: (v) => setState(() => padded = v),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(WInput), 'OK');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(padded, [' ok '], reason: 'no second chip may be committed');
  });

  testWidgets('submitting whitespace does not add a chip', (tester) async {
    List<String> next = const ['sentinel'];
    await tester.pumpWidget(
      wrap(buildList(value: const [], onChanged: (v) => next = v)),
    );

    await tester.enterText(find.byType(WInput), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(next, ['sentinel']);
  });

  // ---------------------------------------------------------------------------
  // Remove
  // ---------------------------------------------------------------------------

  testWidgets('tapping remove drops exactly that chip', (tester) async {
    List<String> next = const [];
    await tester.pumpWidget(
      wrap(
        buildList(
          value: const ['ok', 'degraded', 'critical'],
          onChanged: (v) => next = v,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close).at(1));
    await tester.pump();

    expect(next, ['ok', 'critical']);
  });

  testWidgets('remove control carries the value-specific a11y label', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(buildList(value: const ['ok'], onChanged: (_) {})),
    );

    expect(find.bySemanticsLabel('Remove ok'), findsOneWidget);
  });

  // QA: Backspace on an empty draft removes the last committed value.
  testWidgets('Backspace on an empty draft removes the last committed value', (
    tester,
  ) async {
    List<String> current = const ['ok', 'degraded'];
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => buildList(
            value: current,
            onChanged: (v) => setState(() => current = v),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(WInput));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(current, ['ok']);
  });

  testWidgets('Backspace with draft text present does not remove a chip', (
    tester,
  ) async {
    List<String> current = const ['ok'];
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => buildList(
            value: current,
            onChanged: (v) => setState(() => current = v),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(WInput), 'x');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(current, ['ok']);
  });

  testWidgets(
    'Backspace on an empty draft with no committed values is a no-op',
    (tester) async {
      List<String> current = const [];
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => buildList(
              value: current,
              onChanged: (v) => setState(() => current = v),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(WInput));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(current, isEmpty);
    },
  );

  // ---------------------------------------------------------------------------
  // Every mutation emits a fresh list
  // ---------------------------------------------------------------------------

  testWidgets('each mutation emits a new list rather than mutating the input', (
    tester,
  ) async {
    final original = <String>['ok'];
    List<String>? emitted;
    await tester.pumpWidget(
      wrap(buildList(value: original, onChanged: (v) => emitted = v)),
    );

    await tester.enterText(find.byType(WInput), 'degraded');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(emitted, isNot(same(original)));
    expect(emitted, ['ok', 'degraded']);
    expect(original, ['ok']);
  });

  // ---------------------------------------------------------------------------
  // QA: the critical tone resolves to the destructive container colour in
  // light and dark.
  // ---------------------------------------------------------------------------

  group('critical tone resolves to the destructive container colour', () {
    Color? chipFillColor(WidgetTester tester) {
      final container = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(WBadge),
              matching: find.byType(Container),
            ),
          )
          .first;
      final decoration = container.decoration;
      if (decoration is! BoxDecoration) return null;
      return decoration.color;
    }

    testWidgets('light mode: a real, distinct fill from neutral', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          buildList(
            value: const ['down'],
            onChanged: (_) {},
            tone: StringValueListTone.critical,
          ),
        ),
      );
      final criticalColor = chipFillColor(tester);
      expect(
        criticalColor,
        isNotNull,
        reason: 'the destructive-container fill colour resolved to nothing',
      );
      expect(criticalColor, isNot(const Color(0x00000000)));

      await tester.pumpWidget(
        wrap(
          buildList(
            value: const ['down'],
            onChanged: (_) {},
            tone: StringValueListTone.neutral,
          ),
        ),
      );
      final neutralColor = chipFillColor(tester);

      expect(
        criticalColor,
        isNot(neutralColor),
        reason: 'critical must render a genuinely different fill than neutral',
      );
    });

    testWidgets('dark mode: a real, distinct fill from neutral', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          buildList(
            value: const ['down'],
            onChanged: (_) {},
            tone: StringValueListTone.critical,
          ),
          brightness: Brightness.dark,
        ),
      );
      final criticalColor = chipFillColor(tester);
      expect(criticalColor, isNotNull);
      expect(criticalColor, isNot(const Color(0x00000000)));

      await tester.pumpWidget(
        wrap(
          buildList(
            value: const ['down'],
            onChanged: (_) {},
            tone: StringValueListTone.neutral,
          ),
          brightness: Brightness.dark,
        ),
      );
      final neutralColor = chipFillColor(tester);

      expect(criticalColor, isNot(neutralColor));
    });

    testWidgets('light and dark critical fills differ from each other', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          buildList(
            value: const ['down'],
            onChanged: (_) {},
            tone: StringValueListTone.critical,
          ),
        ),
      );
      final lightColor = chipFillColor(tester);

      await tester.pumpWidget(
        wrap(
          buildList(
            value: const ['down'],
            onChanged: (_) {},
            tone: StringValueListTone.critical,
          ),
          brightness: Brightness.dark,
        ),
      );
      final darkColor = chipFillColor(tester);

      expect(lightColor, isNot(darkColor));
    });
  });
}
