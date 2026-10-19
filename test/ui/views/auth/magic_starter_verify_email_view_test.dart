import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  Future<void> mount(WidgetTester tester, {required String location}) async {
    MagicRoute.page(
      '/auth/verify-email',
      () => const MagicStarterVerifyEmailView(),
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

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Magic.singleton('log', () => LogManager());
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Magic.put(MagicStarterAuthController());
    Auth.fake();
  });

  tearDown(() {
    Auth.unfake();
    Http.unfake();
    MagicRouter.reset();
  });

  testWidgets('replays the mailed link once and reports success', (
    tester,
  ) async {
    final List<String> requests = <String>[];
    Http.fake((request) {
      requests.add(request.url);

      return Http.response(<String, dynamic>{'message': 'ok'});
    });

    await mount(
      tester,
      location:
          '/auth/verify-email?id=7&hash=${'a' * 40}&expires=99&signature=sig',
    );

    expect(requests, ['/email/verify/7/${'a' * 40}']);
    expect(
      find.text(trans('magic_starter.email_verification.verify_success')),
      findsOneWidget,
    );
  });

  testWidgets('a link missing its signature never reaches the API', (
    tester,
  ) async {
    final List<String> requests = <String>[];
    Http.fake((request) {
      requests.add(request.url);

      return Http.response(<String, dynamic>{'message': 'ok'});
    });

    await mount(tester, location: '/auth/verify-email?id=7&hash=abc');

    expect(requests, isEmpty);
    expect(
      find.text(trans('magic_starter.email_verification.verify_failed')),
      findsOneWidget,
    );
  });

  testWidgets('a refused link shows the failure', (tester) async {
    Http.fake(
      (request) => Http.response(<String, dynamic>{
        'message': 'Invalid signature.',
      }, 403),
    );

    await mount(
      tester,
      location:
          '/auth/verify-email?id=7&hash=${'a' * 40}&expires=99&signature=bad',
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    // The reader's wording, not the API's.
    expect(
      find.text(trans('magic_starter.email_verification.verify_failed')),
      findsOneWidget,
    );
    expect(find.text('Invalid signature.'), findsNothing);
  });

  test('the view registers only with email verification', () {
    Config.set('magic_starter.features.email_verification', false);
    expect(MagicStarterManager().view.has('auth.verify_email'), isFalse);

    Config.set('magic_starter.features.email_verification', true);
    addTearDown(
      () => Config.set('magic_starter.features.email_verification', false),
    );
    expect(MagicStarterManager().view.has('auth.verify_email'), isTrue);
  });

  testWidgets('a link whose id or hash is no key never reaches the API', (
    tester,
  ) async {
    // Dio normalises `..` out of a path, so `id=..` sent the reader's bearer
    // to another API path. Only a key-shaped id and a sha1 hash are replayed.
    final List<String> requests = <String>[];
    Http.fake((request) {
      requests.add(request.url);

      return Http.response(<String, dynamic>{'message': 'ok'});
    });

    await mount(
      tester,
      location: '/auth/verify-email?id=..&hash=..&expires=99&signature=sig',
    );

    expect(requests, isEmpty);
    expect(
      find.text(trans('magic_starter.email_verification.verify_failed')),
      findsOneWidget,
    );
  });

  testWidgets('a reader signed in as someone else is not told it is theirs', (
    tester,
  ) async {
    Auth.fake(user: MagicStarterAuthUser.fromMap({'id': 'u-1', 'name': 'A'}));
    Http.fake((request) => Http.response(<String, dynamic>{'message': 'ok'}));

    await mount(
      tester,
      location:
          '/auth/verify-email?id=u-2&hash=${'a' * 40}&expires=99&signature=sig',
    );

    expect(
      find.text(trans('magic_starter.email_verification.verify_success_other')),
      findsOneWidget,
    );
    expect(
      find.text(trans('magic_starter.email_verification.verify_success')),
      findsNothing,
    );
  });
}
