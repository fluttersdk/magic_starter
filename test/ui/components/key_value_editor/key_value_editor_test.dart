import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

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

  Widget wrap(Widget widget) => MaterialApp(
    home: WindTheme(
      data: WindThemeData(),
      child: Scaffold(body: SingleChildScrollView(child: widget)),
    ),
  );

  Widget buildEditor({
    required List<MSKeyValueRow> value,
    required ValueChanged<List<MSKeyValueRow>> onChanged,
  }) => MSKeyValueEditor(
    value: value,
    onChanged: onChanged,
    keyPlaceholder: 'Header',
    valuePlaceholder: 'Value',
    addLabel: 'Add header',
    removeRowLabel: 'Remove row',
  );

  // ---------------------------------------------------------------------------
  // Recipe token assertions
  // ---------------------------------------------------------------------------

  group('keyValueEditorRecipe', () {
    test('root stacks rows; remove is a square ghost', () {
      final slots = keyValueEditorRecipe(variants: const {});
      expect(slots['root'], contains('flex flex-col'));
      // size-11 is the 44dp tap-target floor.
      expect(slots['remove'], contains('size-11'));
      expect(slots['remove'], contains('rounded-md'));
    });
  });

  // ---------------------------------------------------------------------------
  // MSKeyValueRow value type
  // ---------------------------------------------------------------------------

  group('MSKeyValueRow', () {
    test('copyWith replaces only the given field', () {
      const row = MSKeyValueRow(key: 'A', value: '1');
      expect(row.copyWith(value: '2'), isA<MSKeyValueRow>());
      expect(row.copyWith(value: '2').key, 'A');
      expect(row.copyWith(value: '2').value, '2');
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('renders the Add button + the supplied rows', (tester) async {
    await tester.pumpWidget(
      wrap(
        buildEditor(
          value: const [MSKeyValueRow(key: 'Authorization', value: 'Bearer x')],
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('Add header'), findsOneWidget);
    expect(find.byType(MSKeyValueEditor), findsOneWidget);
  });

  testWidgets('Add appends an empty row', (tester) async {
    List<MSKeyValueRow> next = const [];
    await tester.pumpWidget(
      wrap(buildEditor(value: const [], onChanged: (v) => next = v)),
    );
    await tester.tap(find.text('Add header'));
    await tester.pump();
    expect(next.length, 1);
    expect(next.first.key, '');
  });

  testWidgets('editing the key input updates only that row', (tester) async {
    List<MSKeyValueRow> next = const [];
    await tester.pumpWidget(
      wrap(
        buildEditor(
          value: const [MSKeyValueRow(key: '', value: 'Bearer x')],
          onChanged: (v) => next = v,
        ),
      ),
    );

    await tester.enterText(find.byType(WInput).first, 'Authorization');
    await tester.pump();

    expect(next.single.key, 'Authorization');
    expect(next.single.value, 'Bearer x');
  });

  // QA: add then remove emits two fresh lists and never mutates the input.
  testWidgets(
    'add then remove emits two fresh lists, never mutating the input',
    (tester) async {
      final original = <MSKeyValueRow>[
        const MSKeyValueRow(key: 'Authorization', value: 'Bearer x'),
      ];
      final emitted = <List<MSKeyValueRow>>[];
      List<MSKeyValueRow> current = original;

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => buildEditor(
              value: current,
              onChanged: (v) {
                emitted.add(v);
                setState(() => current = v);
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add header'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pump();

      expect(emitted.length, 2);
      expect(emitted[0], isNot(same(original)));
      expect(emitted[1], isNot(same(emitted[0])));
      expect(
        original.length,
        1,
        reason: 'the original list must never be mutated in place',
      );
      expect(emitted[1].length, 1);
      expect(emitted[1].single.key, 'Authorization');
      expect(emitted[1].single.value, 'Bearer x');
    },
  );

  testWidgets('remove-row control carries the supplied a11y label', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        buildEditor(
          value: const [MSKeyValueRow(key: 'A', value: '1')],
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.bySemanticsLabel('Remove row'), findsOneWidget);
  });
}
