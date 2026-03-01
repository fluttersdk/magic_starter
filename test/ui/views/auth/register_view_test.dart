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

  group('MagicStarterRegisterView', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.put(StarterAuthController());
    });

    testWidgets('shows newsletter checkbox when feature enabled',
        (tester) async {
      Config.set('magic_starter.features.newsletter', true);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('hides newsletter checkbox when feature disabled',
        (tester) async {
      Config.set('magic_starter.features.newsletter', false);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('shows email field in email-only mode (default)',
        (tester) async {
      Config.set('magic_starter.auth.email', true);
      Config.set('magic_starter.auth.phone', false);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      await tester.pumpAndSettle();

      expect(find.widgetWithText(WFormInput, trans('attributes.email')),
          findsOneWidget);
      expect(find.widgetWithText(WFormInput, trans('attributes.phone')),
          findsNothing);
    });

    testWidgets('shows phone field in phone-only mode', (tester) async {
      Config.set('magic_starter.auth.email', false);
      Config.set('magic_starter.auth.phone', true);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      await tester.pumpAndSettle();

      expect(find.widgetWithText(WFormInput, trans('attributes.phone')),
          findsOneWidget);
      expect(find.widgetWithText(WFormInput, trans('attributes.email')),
          findsNothing);
    });

    testWidgets('shows toggle buttons in both mode', (tester) async {
      Config.set('magic_starter.auth.email', true);
      Config.set('magic_starter.auth.phone', true);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      await tester.pumpAndSettle();

      expect(find.widgetWithText(WButton, trans('attributes.email')),
          findsOneWidget);
      expect(find.widgetWithText(WButton, trans('attributes.phone')),
          findsOneWidget);
    });
  });
}
