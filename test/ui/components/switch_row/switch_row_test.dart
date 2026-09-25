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

  /// Wraps [widget] in a [MaterialApp] with a default [WindTheme], inside a
  /// column of [width] so a long label has to wrap rather than grow.
  Widget wrap(Widget widget, {double width = 390}) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: widget),
          ),
        ),
      ),
    );
  }

  /// A [MSSwitchRow] with the short English label most tests need.
  MSSwitchRow row({bool value = false, ValueChanged<bool>? onChanged}) {
    return MSSwitchRow(
      label: 'Notify subscribers',
      value: value,
      onChanged: onChanged ?? (_) {},
    );
  }

  group('MSSwitchRow', () {
    testWidgets('renders the label beside the switch', (tester) async {
      await tester.pumpWidget(wrap(row(value: true)));

      expect(find.text('Notify subscribers'), findsOneWidget);
      expect(find.byType(MSSwitch), findsOneWidget);
    });

    testWidgets('names the switch with its label', (tester) async {
      await tester.pumpWidget(wrap(row()));

      final MSSwitch control = tester.widget<MSSwitch>(find.byType(MSSwitch));
      expect(control.semanticLabel, 'Notify subscribers');
    });

    testWidgets('reports the flipped value when toggled', (tester) async {
      final List<bool> reported = <bool>[];
      await tester.pumpWidget(wrap(row(onChanged: reported.add)));

      await tester.tap(find.byType(MSSwitch));
      await tester.pump();

      expect(reported, <bool>[true]);
    });

    testWidgets('wraps a 200-character label instead of overflowing', (
      tester,
    ) async {
      // Regression for the escalation editor's overflow at 390pt: the label
      // must shrink into a flex share rather than force the row wider than
      // its column. A RenderFlex overflow surfaces as an exception.
      final String label = 'A' * 200;
      await tester.pumpWidget(
        wrap(
          MSSwitchRow(label: label, value: true, onChanged: (_) {}),
          width: 320,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(label), findsOneWidget);
    });
  });
}
