import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsData;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart' show ButtonIntent;
import 'package:magic_starter/src/ui/components/header_action/index.dart';

/// Pins [MSHeaderAction]'s two forms and the label that has to survive the
/// swap between them.
void main() {
  /// Renders [action] at [width] inside a default [WindTheme].
  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    MSHeaderAction action,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 900)),
          child: WindTheme(
            data: WindThemeData(),
            child: Scaffold(body: action),
          ),
        ),
      ),
    );
  }

  /// A `New monitor` action, enabled unless [enabled] says otherwise.
  ///
  /// `enabled` is a flag rather than a nullable callback because the obvious
  /// spelling, `onPressed ?? () {}`, turns the disabled case into a no-op
  /// callback and the disabled test passes without ever reaching that branch.
  MSHeaderAction newMonitor({
    VoidCallback? onTap,
    bool enabled = true,
    ButtonIntent? intent,
  }) {
    return MSHeaderAction(
      icon: Icons.add,
      label: 'New monitor',
      intent: intent ?? ButtonIntent.primary,
      onPressed: enabled ? (onTap ?? () {}) : null,
    );
  }

  testWidgets(
    'a narrow width renders the glyph and keeps the label reachable',
    (tester) async {
      await pumpAt(tester, 402, newMonitor());

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(
        find.text('New monitor'),
        findsNothing,
        reason: 'the label is what costs a header a row of its own on a phone',
      );

      // The label moved rather than disappeared. Without this an icon-only
      // control reaches a screen reader as an unnamed button.
      final SemanticsData data = tester
          .getSemantics(find.byType(MSHeaderAction))
          .getSemanticsData();
      expect(data.label, 'New monitor');
      expect(
        data.hasAction(SemanticsAction.tap),
        isTrue,
        reason:
            'the name and the action have to sit on ONE node; before the '
            'merge the named node carried no action and the actionable node no '
            'name',
      );
    },
  );

  testWidgets('a lg-and-up width renders the labelled button', (tester) async {
    await pumpAt(tester, 1280, newMonitor());

    expect(find.text('New monitor'), findsOneWidget);
    expect(
      find.byIcon(Icons.add),
      findsNothing,
      reason:
          'a desktop header has room for the name; the glyph is the '
          'compromise a phone needs',
    );
  });

  testWidgets('a null callback reports the glyph as a disabled button', (
    tester,
  ) async {
    await pumpAt(tester, 402, newMonitor(enabled: false));

    final SemanticsData data = tester
        .getSemantics(find.byType(MSHeaderAction))
        .getSemanticsData();
    expect(data.label, 'New monitor');
    expect(
      data.hasAction(SemanticsAction.tap),
      isFalse,
      reason:
          'a null callback used to keep the anchor, so the glyph still '
          'announced itself as tappable while doing nothing',
    );
  });

  testWidgets('a tap fires the callback on both forms', (tester) async {
    for (final double width in [402.0, 1280.0]) {
      int taps = 0;
      await pumpAt(tester, width, newMonitor(onTap: () => taps++));

      await tester.tap(
        width < 1024 ? find.byIcon(Icons.add) : find.text('New monitor'),
      );
      await tester.pump();

      expect(taps, 1, reason: 'the action must fire at ${width}pt');
    }
  });
}
