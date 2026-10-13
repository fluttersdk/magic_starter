import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    String location = '/auth/reset-password',
  }) async {
    MagicRoute.page(
      '/auth/reset-password',
      () => const MagicStarterResetPasswordView(),
    );
    MagicRouter.instance.setInitialLocation(location);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: MagicRouter.instance.routerConfig,
        builder: (context, child) => WindTheme(
          data: WindThemeData(),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void setUpApp() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Magic.singleton('log', () => LogManager());
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Magic.put(MagicStarterAuthController());
  }

  group('MagicStarterResetPasswordView — slot injection', () {
    setUp(setUpApp);

    tearDown(MagicRouter.reset);

    testWidgets('renders header slot when registered', (tester) async {
      MagicStarter.view.slot(
        'auth.reset_password',
        'header',
        (ctx) => const Text('Custom Header'),
      );

      await mount(tester);

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('renders footer slot when registered', (tester) async {
      MagicStarter.view.slot(
        'auth.reset_password',
        'footer',
        (ctx) => const Text('Custom Footer'),
      );

      await mount(tester);

      expect(find.text('Custom Footer'), findsOneWidget);
    });
  });

  group('MagicStarterResetPasswordView autofill', () {
    setUp(setUpApp);

    tearDown(MagicRouter.reset);

    testWidgets('offers a new password on both password fields', (
      tester,
    ) async {
      await mount(tester);

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
      await mount(tester);

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

  group('MagicStarterResetPasswordView — the mailed link', () {
    setUp(setUpApp);

    tearDown(() {
      Http.unfake();
      MagicRouter.reset();
    });

    testWidgets('posts the token and email read from the query string', (
      tester,
    ) async {
      // The backend mails `/auth/reset-password?token=...&email=...`: the route
      // has no `:token` segment, so a path read posted an empty token and the
      // backend answered 422.
      final List<Object?> bodies = <Object?>[];
      Http.fake((request) {
        if (request.url == '/auth/reset-password') bodies.add(request.data);

        return Http.response(<String, dynamic>{'message': 'ok'});
      });

      await mount(
        tester,
        location: '/auth/reset-password?token=abc&email=a@b.co',
      );

      final Finder fields = find.byType(EditableText);
      await tester.enterText(fields.at(1), 'new-password-1');
      await tester.enterText(fields.at(2), 'new-password-1');
      await tester.tap(find.text(trans('auth.reset_password_button')));
      await tester.pumpAndSettle();

      expect(bodies, hasLength(1));
      expect(bodies.single, <String, dynamic>{
        'token': 'abc',
        'email': 'a@b.co',
        'password': 'new-password-1',
        'password_confirmation': 'new-password-1',
      });
    });
  });
}
