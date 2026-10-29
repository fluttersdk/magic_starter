import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../ui/components/field_theme_fixture.dart';

// The one string a host puts in `MagicStarterFormTheme.inputClassName` to make
// the starter's `WFormInput` forms and its `WFormSelect`s (the team role select
// and the two language selects) 44 px tall with 17 on 22 type. An input paints
// its border inside its padding and a select trigger adds it, so no `py-*` alone
// serves both; the minimum height does: it lifts the input from 42 to 44 and
// leaves the select, which is 10 + 22 + 10 + 2, where it is. The docs quote this
// string and these numbers, so they are pinned here.
const _sizeRun = 'py-[10px] min-h-11 text-[17px] leading-[22px]';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    // The way a host sets it: copy the active theme, change the one string.
    MagicStarter.useFormTheme(
      MagicStarter.formTheme.copyWith(
        inputClassName: const MagicStarterFormTheme().inputClassName
            .replaceFirst('py-3', _sizeRun),
      ),
    );
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  test('the adoption guide quotes the same string', () {
    final guide = File('doc/guides/wind-theme-adoption.md').readAsStringSync();

    expect(guide, contains(_sizeRun));
  });

  test('the host string carries the size run and keeps the rest', () {
    final input = MagicStarter.formTheme.inputClassName;

    expect(input, contains(_sizeRun));
    expect(input, isNot(contains('py-3')));
    expect(input, contains('px-3'));
    expect(input, contains('rounded-lg'));
    expect(input, contains('border'));
  });

  for (final brightness in Brightness.values) {
    for (final entry in {'phone': kPhone, 'desktop': kDesktop}.entries) {
      final label = '${brightness.name} ${entry.key}';

      testWidgets('WFormInput is 44 px tall with a centred 22 px line, '
          '$label', (tester) async {
        await pumpControlAt(
          tester,
          entry.value,
          WFormInput(
            initialValue: 'Typed',
            placeholder: 'Enter text',
            className: MagicStarter.formTheme.inputClassName,
          ),
          brightness: brightness,
        );

        final input = tester.getRect(find.byType(WInput));
        final line = tester.getRect(find.byType(EditableText));

        expect(input.height, 44);
        expect(line.height, 22);
        expect(line.center.dy, closeTo(input.center.dy, 0.5));
        expect(
          tester
              .state<EditableTextState>(find.byType(EditableText))
              .widget
              .style
              .fontSize,
          17,
        );
      });

      testWidgets('WFormInput centres its placeholder line the same way, '
          '$label', (tester) async {
        await pumpControlAt(
          tester,
          entry.value,
          WFormInput(
            placeholder: 'Enter text',
            className: MagicStarter.formTheme.inputClassName,
          ),
          brightness: brightness,
        );

        final input = tester.getRect(find.byType(WInput));
        final placeholder = tester.getRect(find.text('Enter text'));

        expect(input.height, 44);
        expect(placeholder.height, 22);
        expect(placeholder.center.dy, closeTo(input.center.dy, 0.5));
      });

      testWidgets('WFormSelect is 44 px tall with a centred 22 px line, '
          '$label', (tester) async {
        await pumpControlAt(
          tester,
          entry.value,
          WFormSelect<String>(
            value: 'a',
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
            className: MagicStarter.formTheme.inputClassName,
          ),
          brightness: brightness,
        );

        final trigger = tester.getRect(find.byType(WSelect<String>));
        final line = tester.getRect(find.text('Option A'));

        expect(trigger.height, 44);
        expect(line.height, 22);
        expect(line.center.dy, closeTo(trigger.center.dy, 0.5));
      });
    }
  }

  testWidgets('the two are the same height at the default text size, so one '
      'string serves both', (tester) async {
    await pumpControlAt(
      tester,
      kPhone,
      Column(
        children: [
          WFormInput(
            initialValue: 'Typed',
            className: MagicStarter.formTheme.inputClassName,
          ),
          WFormSelect<String>(
            value: 'a',
            options: const [SelectOption(value: 'a', label: 'Option A')],
            onChange: (_) {},
            className: MagicStarter.formTheme.inputClassName,
          ),
        ],
      ),
    );

    expect(
      tester.getSize(find.byType(WInput)).height,
      tester.getSize(find.byType(WSelect<String>)).height,
    );
  });

  // The other two paddings the docs rule out, measured so the table in the
  // guide is a pinned fact and not a remembered one.
  for (final entry in {
    'py-[11px] text-[17px] leading-[22px]': (input: 44.0, select: 46.0),
    'py-2.5 text-[17px] leading-[22px]': (input: 42.0, select: 44.0),
  }.entries) {
    testWidgets('`${entry.key}` is ${entry.value.input} for the input and '
        '${entry.value.select} for the select', (tester) async {
      final className = const MagicStarterFormTheme().inputClassName
          .replaceFirst('py-3', entry.key);
      await pumpControlAt(
        tester,
        kPhone,
        Column(
          children: [
            WFormInput(initialValue: 'Typed', className: className),
            WFormSelect<String>(
              value: 'a',
              options: const [SelectOption(value: 'a', label: 'Option A')],
              onChange: (_) {},
              className: className,
            ),
          ],
        ),
      );

      expect(tester.getSize(find.byType(WInput)).height, entry.value.input);
      expect(
        tester.getSize(find.byType(WSelect<String>)).height,
        entry.value.select,
      );
    });
  }
}
