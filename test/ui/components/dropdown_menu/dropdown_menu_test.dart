import 'package:flutter/material.dart'
    hide DropdownMenu, DropdownMenuItem, DropdownMenuEntry;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: Center(child: widget)),
      ),
    );
  }

  group('DropdownMenu', () {
    testWidgets('renders trigger child', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownMenu(
          items: const [DropdownMenuItem(label: 'Item 1')],
          child: const Text('open menu'),
        ),
      ));

      expect(find.text('open menu'), findsOneWidget);
    });

    testWidgets('items are not visible when closed', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownMenu(
          items: const [DropdownMenuItem(label: 'Hidden Item')],
          child: const Text('open menu'),
        ),
      ));

      expect(find.text('Hidden Item'), findsNothing);
    });

    testWidgets('tapping trigger opens the menu items', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownMenu(
          items: const [DropdownMenuItem(label: 'Visible Item')],
          child: const Text('open menu'),
        ),
      ));

      await tester.tap(find.text('open menu'));
      await tester.pump();

      expect(find.text('Visible Item'), findsOneWidget);
    });

    testWidgets('tapping an item invokes onTap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(wrap(
        DropdownMenu(
          items: [
            DropdownMenuItem(
              label: 'Tap me',
              onTap: () => tapped = true,
            ),
          ],
          child: const Text('open menu'),
        ),
      ));

      await tester.tap(find.text('open menu'));
      await tester.pump();
      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('DropdownMenuItem disabled label is rendered in menu',
        (tester) async {
      await tester.pumpWidget(wrap(
        DropdownMenu(
          items: const [
            DropdownMenuItem(label: 'Normal'),
            DropdownMenuItem(label: 'Disabled', disabled: true),
          ],
          child: const Text('open menu'),
        ),
      ));

      await tester.tap(find.text('open menu'));
      await tester.pump();

      // Both labels should be visible; the disabled item is rendered but
      // without a tap handler (no WAnchor wrapper).
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // DropdownMenuItem data class
  // ---------------------------------------------------------------------------

  test('DropdownMenuItem holds label, onTap, disabled', () {
    const item = DropdownMenuItem(label: 'Test', disabled: false);
    // Data-class field assertions use the type directly (not tester.widget).
    expect(item.label, 'Test');
    expect(item.disabled, isFalse);
    expect(item.onTap, isNull);
  });

  // Verify DropdownMenu is re-exported from index.dart
  test('DropdownMenu is re-exported from index.dart', () {
    expect(DropdownMenu, isNotNull);
  });
}
