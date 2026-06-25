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

  group('tabs recipe', () {
    test('list slot contains border-b', () {
      final cls = tabsRecipe();
      expect(cls['list'], contains('border-b'));
    });

    test('tab slot contains px-', () {
      final cls = tabsRecipe();
      expect(cls['tab'], contains('px-'));
    });

    test('panel slot is non-empty', () {
      final cls = tabsRecipe();
      expect(cls['panel'], isNotEmpty);
    });

    test('all three required slots are present', () {
      final cls = tabsRecipe();
      expect(cls.keys, containsAll(['list', 'tab', 'panel']));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget interaction tests
  // ---------------------------------------------------------------------------

  group('Tabs widget', () {
    testWidgets('renders first panel by default', (tester) async {
      await tester.pumpWidget(
        wrap(
          Tabs(
            tabs: const ['Tab 1', 'Tab 2'],
            selectedIndex: 0,
            onChanged: (_) {},
            panelBuilder: (i) =>
                i == 0 ? const Text('Panel 1') : const Text('Panel 2'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Panel 1'), findsOneWidget);
      expect(find.text('Panel 2'), findsNothing);
    });

    testWidgets('calls onChanged when a tab is tapped', (tester) async {
      int? changed;
      await tester.pumpWidget(
        wrap(
          Tabs(
            tabs: const ['Tab 1', 'Tab 2'],
            selectedIndex: 0,
            onChanged: (i) => changed = i,
            panelBuilder: (i) => Text('Panel $i'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tab 2'));
      await tester.pumpAndSettle();

      expect(changed, equals(1));
    });

    testWidgets('renders second panel when selectedIndex is 1', (tester) async {
      await tester.pumpWidget(
        wrap(
          Tabs(
            tabs: const ['Tab 1', 'Tab 2'],
            selectedIndex: 1,
            onChanged: (_) {},
            panelBuilder: (i) =>
                i == 0 ? const Text('Panel 1') : const Text('Panel 2'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Panel 2'), findsOneWidget);
      expect(find.text('Panel 1'), findsNothing);
    });
  });
}
