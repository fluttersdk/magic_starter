import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
  }

  group('MagicStarterResetPasswordView — slot injection', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.put(MagicStarterAuthController());
    });

    testWidgets('renders header slot when registered', (tester) async {
      MagicStarter.view.slot(
        'auth.reset_password',
        'header',
        (ctx) => const Text('Custom Header'),
      );

      await tester.pumpWidget(wrap(const MagicStarterResetPasswordView()));
      await tester.pumpAndSettle();

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('renders footer slot when registered', (tester) async {
      MagicStarter.view.slot(
        'auth.reset_password',
        'footer',
        (ctx) => const Text('Custom Footer'),
      );

      await tester.pumpWidget(wrap(const MagicStarterResetPasswordView()));
      await tester.pumpAndSettle();

      expect(find.text('Custom Footer'), findsOneWidget);
    });
  });

  group('MagicStarterResetPasswordView autofill', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.put(MagicStarterAuthController());
    });

    testWidgets('offers a new password on both password fields', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterResetPasswordView()));
      await tester.pumpAndSettle();

      final hints = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((field) => field.autofillHints?.toList())
          .toList();

      expect(hints.sublist(1), [
        [AutofillHints.newPassword],
        [AutofillHints.newPassword],
      ]);
    });

    testWidgets('groups the fields and cancels the context on dispose', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterResetPasswordView()));
      await tester.pumpAndSettle();

      final group = tester.widget<AutofillGroup>(find.byType(AutofillGroup));
      expect(group.onDisposeAction, AutofillContextAction.cancel);
      expect(
        find.descendant(
          of: find.byType(AutofillGroup),
          matching: find.byType(EditableText),
        ),
        findsNWidgets(3),
      );
    });
  });
}
