import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/widgets/magic_starter_social_divider.dart';

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: widget,
        ),
      ),
    );
  }

  group('MagicStarterSocialDivider', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('magic_starter', () => MagicStarterManager());
    });

    testWidgets('renders divider with translated text', (tester) async {
      await tester.pumpWidget(
        wrap(const MagicStarterSocialDivider()),
      );

      // trans() returns the key when no translation is loaded
      expect(find.text('auth.or_continue_with'), findsOneWidget);
    });

    testWidgets('contains horizontal divider lines', (tester) async {
      await tester.pumpWidget(
        wrap(const MagicStarterSocialDivider()),
      );

      // Should have WDiv elements for the divider lines
      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Theme consumption tests
  // -------------------------------------------------------------------------

  group('theme consumption', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('magic_starter', () => MagicStarterManager());
    });

    testWidgets('custom socialDividerTextClassName is used for divider text',
        (tester) async {
      MagicStarter.manager.authTheme = const MagicStarterAuthTheme(
        socialDividerTextClassName: 'custom-divider-text',
      );

      await tester.pumpWidget(
        wrap(const MagicStarterSocialDivider()),
      );

      final wText = tester.widget<WText>(find.byType(WText));
      expect(wText.className, contains('custom-divider-text'));
    });
  });
}
