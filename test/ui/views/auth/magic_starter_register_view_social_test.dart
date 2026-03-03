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

  group('MagicStarterRegisterView — social login', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.singleton('log', () => LogManager());
      Magic.put(MagicStarterAuthController());
    });

    testWidgets('does not show social login when feature disabled (default)',
        (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      expect(find.byType(MagicStarterSocialDivider), findsNothing);
    });

    testWidgets(
        'does not show social login when feature enabled but no builder',
        (tester) async {
      Config.set('magic_starter.features.social_login', true);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      expect(find.byType(MagicStarterSocialDivider), findsNothing);
    });

    testWidgets(
        'shows social login when feature enabled AND builder registered',
        (tester) async {
      Config.set('magic_starter.features.social_login', true);
      MagicStarter.useSocialLogin((context, isLoading) {
        return const SizedBox(key: Key('social-buttons'));
      });

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      expect(find.byType(MagicStarterSocialDivider), findsOneWidget);
      expect(find.byKey(const Key('social-buttons')), findsOneWidget);
    });

    testWidgets('passes isLoading=false to builder when not submitting',
        (tester) async {
      Config.set('magic_starter.features.social_login', true);
      bool? receivedIsLoading;
      MagicStarter.useSocialLogin((context, isLoading) {
        receivedIsLoading = isLoading;
        return const SizedBox();
      });

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      expect(receivedIsLoading, isFalse);
    });
  });
}
