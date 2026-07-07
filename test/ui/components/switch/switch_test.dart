import 'package:flutter/material.dart' hide Switch;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/switch/switch.preview.dart';

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

  group('switch recipe', () {
    test('track recipe emits rounded-full token', () {
      final cls = switchTrackRecipe();
      expect(cls, contains('rounded-full'));
    });

    test('track recipe emits checked: state prefix token for bg-primary', () {
      final cls = switchTrackRecipe();
      expect(cls, contains('checked:bg-primary'));
    });

    test('thumb recipe emits rounded-full token', () {
      final cls = switchThumbRecipe();
      expect(cls, contains('rounded-full'));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('Switch renders a WSwitch', (tester) async {
    await tester.pumpWidget(
      wrap(Switch(value: false, onChanged: (_) {})),
    );
    expect(find.byType(WSwitch), findsOneWidget);
  });

  testWidgets('Switch reflects value prop on WSwitch', (tester) async {
    await tester.pumpWidget(
      wrap(Switch(value: true, onChanged: (_) {})),
    );
    final widget = tester.widget<WSwitch>(find.byType(WSwitch));
    expect(widget.value, isTrue);
  });

  testWidgets('Switch fires onChanged when tapped', (tester) async {
    bool? newValue;
    await tester.pumpWidget(
      wrap(Switch(value: false, onChanged: (v) => newValue = v)),
    );
    await tester.tap(find.byType(WSwitch));
    await tester.pump();
    expect(newValue, isTrue);
  });

  testWidgets('Switch applies track className with bg-surface-container-high',
      (tester) async {
    await tester.pumpWidget(
      wrap(Switch(value: false, onChanged: (_) {})),
    );
    final widget = tester.widget<WSwitch>(find.byType(WSwitch));
    expect(widget.className, contains('bg-surface-container-high'));
  });

  testWidgets('Switch preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const SwitchPreview()));
    await tester.pump();
    expect(find.byType(SwitchPreview), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Switch appends caller className onto track and thumb recipes',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Switch(
          value: false,
          onChanged: (_) {},
          className: 'mt-10',
          thumbClassName: 'mb-10',
        ),
      ),
    );
    final widget = tester.widget<WSwitch>(find.byType(WSwitch));
    expect(widget.className, contains('rounded-full'));
    expect(widget.className, contains('mt-10'));
    expect(widget.thumbClassName, contains('bg-surface'));
    expect(widget.thumbClassName, contains('mb-10'));
  });
}
