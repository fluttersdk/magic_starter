import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/http/controllers/auth_controller.dart';
import 'package:magic_starter/src/ui/views/auth/register_view.dart';

void main() {
  group('MagicStarterRegisterView', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      StarterAuthController.instance;
    });

    testWidgets('shows newsletter checkbox when feature enabled',
        (tester) async {
      Config.set('magic_starter.features.newsletter', true);

      await tester.pumpWidget(
        MagicApplication(
          child: const MagicStarterRegisterView(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text(trans('magic_starter.newsletter.subscribe_label')),
          findsOneWidget);
    });

    testWidgets('hides newsletter checkbox when feature disabled',
        (tester) async {
      Config.set('magic_starter.features.newsletter', false);

      await tester.pumpWidget(
        MagicApplication(
          child: const MagicStarterRegisterView(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text(trans('magic_starter.newsletter.subscribe_label')),
          findsNothing);
    });
  });
}
