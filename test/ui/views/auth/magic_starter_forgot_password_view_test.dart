import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: SingleChildScrollView(child: widget),
        ),
      ),
    );
  }

  group('MagicStarterForgotPasswordView — slot injection', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.put(MagicStarterAuthController());
    });

    testWidgets('renders header slot when registered', (tester) async {
      MagicStarter.view.slot(
        'auth.forgot_password',
        'header',
        (ctx) => const Text('Custom Header'),
      );

      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('renders footer slot when registered', (tester) async {
      MagicStarter.view.slot(
        'auth.forgot_password',
        'footer',
        (ctx) => const Text('Custom Footer'),
      );

      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      expect(find.text('Custom Footer'), findsOneWidget);
    });
  });
}
