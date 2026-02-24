import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/ui/widgets/social_login_divider.dart';

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
}
