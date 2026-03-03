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
      Magic.put(MagicStarterAuthController());
    });

    testWidgets('shows newsletter checkbox when feature enabled',
        (tester) async {
      Config.set('magic_starter.features.newsletter', true);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      await tester.pumpAndSettle();

      expect(find.byType(WFormCheckbox), findsOneWidget);
    });

    testWidgets('hides newsletter checkbox when feature disabled',
        (tester) async {
      Config.set('magic_starter.features.newsletter', false);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      await tester.pumpAndSettle();

      expect(find.byType(WFormCheckbox), findsNothing);
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

    testWidgets('shows phone field without country code in phone-only mode',
        (tester) async {
      Config.set('magic_starter.auth.email', false);
      Config.set('magic_starter.auth.phone', true);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      await tester.pumpAndSettle();

      expect(find.widgetWithText(WFormInput, trans('attributes.phone')),
          findsOneWidget);
      expect(find.widgetWithText(WFormInput, trans('attributes.phone_country')),
          findsNothing);
      expect(find.widgetWithText(WFormInput, trans('attributes.email')),
          findsNothing);
    });

    testWidgets(
        'shows both email and phone fields without country code in both mode',
        (tester) async {
      Config.set('magic_starter.auth.email', true);
      Config.set('magic_starter.auth.phone', true);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      await tester.pumpAndSettle();

      // Register shows both fields simultaneously — no toggle.
      expect(find.widgetWithText(WFormInput, trans('attributes.email')),
          findsOneWidget);
      expect(find.widgetWithText(WFormInput, trans('attributes.phone')),
          findsOneWidget);
      expect(find.widgetWithText(WFormInput, trans('attributes.phone_country')),
          findsNothing);
    });

    testWidgets('hides legal links when no URLs configured', (tester) async {
      // No legal config set — should not show any legal text.
      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.terms_of_service')), findsNothing);
      expect(find.text(trans('auth.privacy_policy')), findsNothing);
    });

    testWidgets('shows terms link when terms_url is configured',
        (tester) async {
      Config.set('magic_starter.legal.terms_url', 'https://example.com/terms');

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.agree_to_legal')), findsOneWidget);
      expect(find.text(trans('auth.terms_of_service')), findsOneWidget);
      expect(find.text(trans('auth.privacy_policy')), findsNothing);
    });

    testWidgets('shows privacy link when privacy_url is configured',
        (tester) async {
      Config.set(
        'magic_starter.legal.privacy_url',
        'https://example.com/privacy',
      );

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.agree_to_legal')), findsOneWidget);
      expect(find.text(trans('auth.privacy_policy')), findsOneWidget);
      expect(find.text(trans('auth.terms_of_service')), findsNothing);
    });

    testWidgets('shows both legal links when both URLs are configured',
        (tester) async {
      Config.set('magic_starter.legal.terms_url', 'https://example.com/terms');
      Config.set(
        'magic_starter.legal.privacy_url',
        'https://example.com/privacy',
      );

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.agree_to_legal')), findsOneWidget);
      expect(find.text(trans('auth.terms_of_service')), findsOneWidget);
      expect(find.text(trans('auth.privacy_policy')), findsOneWidget);
      expect(find.text(trans('auth.legal_and')), findsOneWidget);
    });
  });
}
