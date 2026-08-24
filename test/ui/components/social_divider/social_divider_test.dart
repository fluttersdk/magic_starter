import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/social_divider/social_divider.preview.dart';

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
  // Behavior gate: these assertions came from the pre-MS-prefix alias test.
  // ---------------------------------------------------------------------------

  testWidgets('SocialDivider renders divider with translated text', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSSocialDivider()));
    // trans() returns the key when no translation is loaded
    expect(find.text('auth.or_continue_with'), findsOneWidget);
  });

  testWidgets('SocialDivider contains WDiv and WText elements', (tester) async {
    await tester.pumpWidget(wrap(const MSSocialDivider()));
    expect(find.byType(WDiv), findsWidgets);
    expect(find.byType(WText), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Theme consumption
  // ---------------------------------------------------------------------------

  group('theme consumption', () {
    testWidgets('custom socialDividerTextClassName is applied', (tester) async {
      MagicStarter.manager.authTheme = const MagicStarterAuthTheme(
        socialDividerTextClassName: 'custom-divider-text',
      );
      await tester.pumpWidget(wrap(const MSSocialDivider()));
      final wText = tester.widget<WText>(find.byType(WText));
      expect(wText.className, contains('custom-divider-text'));
    });
  });

  testWidgets('SocialDivider preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const SocialDividerPreview()));
    await tester.pump();
    expect(find.byType(SocialDividerPreview), findsOneWidget);
  });
}
