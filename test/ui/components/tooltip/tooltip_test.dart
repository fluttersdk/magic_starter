import 'package:flutter/material.dart' hide Tooltip;
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

  group('Tooltip', () {
    testWidgets('renders trigger child', (tester) async {
      await tester.pumpWidget(wrap(
        MSTooltip(
          content: const Text('tooltip text'),
          child: const Text('hover me'),
        ),
      ));

      expect(find.text('hover me'), findsOneWidget);
    });

    testWidgets('tooltip content is not visible when closed', (tester) async {
      await tester.pumpWidget(wrap(
        MSTooltip(
          content: const Text('hidden tooltip'),
          child: const Text('hover me'),
        ),
      ));

      // Content should not be in the tree when popover is closed.
      expect(find.text('hidden tooltip'), findsNothing);
    });

    testWidgets('has className prop', (tester) async {
      await tester.pumpWidget(wrap(
        MSTooltip(
          content: const Text('tip'),
          className: 'bg-gray-900 text-white',
          child: const Text('trigger'),
        ),
      ));

      final tooltip = tester.widget<MSTooltip>(find.byType(MSTooltip));
      expect(tooltip.className, 'bg-gray-900 text-white');
    });
  });

  // Verify Tooltip is re-exported from index.dart
  test('Tooltip is re-exported from index.dart', () {
    expect(MSTooltip, isNotNull);
  });

  // ---------------------------------------------------------------------------
  // Caller className append (WIND-1)
  // ---------------------------------------------------------------------------

  testWidgets('Tooltip panel appends caller className onto the default',
      (tester) async {
    await tester.pumpWidget(wrap(
      MSTooltip(
        className: 'mt-10',
        content: const Text('tip'),
        child: const Text('trigger'),
      ),
    ));
    final popover = tester.widget<WPopover>(find.byType(WPopover));
    expect(popover.className, contains('bg-surface-container-high'));
    expect(popover.className, contains('mt-10'));
  });
}
