import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The one-time code a landing page hands over.
const String _code = 'hnd_Q2xhaW1Db2RlRm9yVGhlVGVzdA';

/// The session token the exchange answers with.
const String _token = '42|AbCdEfGhIjKlMnOpQrStUvWxYz0123456789abcd';

/// The handed account's email: shown on the confirmation, logged nowhere.
const String _email = 'ada@example.com';

/// The package's shipped English catalogue, flattened to the dotted keys
/// `trans()` reads, so a key the screen uses that the stub lacks renders raw
/// and fails here.
class _ShippedCatalogueLoader implements TranslationLoader {
  const _ShippedCatalogueLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final Map<String, dynamic> stub =
        jsonDecode(File('assets/stubs/install/en.stub').readAsStringSync())
            as Map<String, dynamic>;
    final Map<String, dynamic> flat = {};

    void walk(String prefix, Map<String, dynamic> node) {
      for (final MapEntry<String, dynamic> entry in node.entries) {
        final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        final Object? value = entry.value;
        if (value is Map<String, dynamic>) {
          walk(key, value);
        } else {
          flat[key] = value;
        }
      }
    }

    walk('', stub);

    return flat;
  }
}

Map<String, dynamic> _session({Object? next = '/monitors/42'}) {
  return {
    'data': {
      'token': _token,
      'user': {'id': 'user-ada', 'name': 'Ada', 'email': _email},
      'next': next,
    },
  };
}

void main() {
  late FakeAuthManager auth;
  late FakeLogManager log;
  late FakeNetworkDriver server;
  late int signOuts;

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Config.set('magic_starter.features.handoff', true);
    Config.set('magic_starter.features.two_factor', true);
    setUpMagicStarterForTests();
    log = Log.fake();
    auth = Auth.fake();
    signOuts = 0;
    MagicStarter.manager.beforeLogout(() async => signOuts++);
    Translator.instance.setLoader(const _ShippedCatalogueLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    MagicRouter.instance.pullIntendedUrl();
    Auth.unfake();
    Log.unfake();
    Translator.reset();
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  /// Makes [answer] the exchange's answer, through the controller's own
  /// driver seam.
  void arrange({MagicResponse? answer}) {
    server = FakeNetworkDriver(
      stubs: (MagicRequest request) => answer ?? Http.response(_session()),
    );
    Magic.put<MagicStarterHandoffController>(
      MagicStarterHandoffController(driver: () => server),
    );
  }

  void signInBob() {
    auth = Auth.fake(
      user: MagicStarter.createUser({
        'id': 'user-bob',
        'name': 'Bob',
        'email': 'bob@example.com',
      }),
    );
  }

  /// Opens `/auth/handoff` with [query] behind a real router and lets the
  /// handoff settle.
  Future<void> visit(WidgetTester tester, Map<String, String> query) async {
    MagicRoute.page('/', () => const Text('home-page'));
    MagicRoute.page('/auth/login', () => const Text('login-page'));
    MagicRoute.page('/auth/register', () => const Text('register-page'));
    MagicRoute.page(
      '/auth/two-factor-challenge',
      () => const Text('challenge-page'),
    );
    MagicRoute.page('/monitors/42', () => const Text('monitor-page'));
    MagicRoute.page('/teams', () => const Text('teams-page'));
    MagicRoute.page(
      '/auth/handoff',
      () => MagicStarter.view.make('auth.handoff'),
    );
    MagicRouter.instance.setInitialLocation(
      Uri(
        path: '/auth/handoff',
        queryParameters: query.isEmpty ? null : query,
      ).toString(),
    );

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

  /// Fails when the code or the token reached the screen, or the code, the
  /// token or the email reached any log line.
  void expectNeverEchoed() {
    expect(find.textContaining(_code), findsNothing);
    expect(find.textContaining('AbCdEfGhIjKl'), findsNothing);
    for (final FakeLogEntry entry in log.entries) {
      final String line = '${entry.message} ${entry.context}';
      expect(line, isNot(contains(_code)));
      expect(line, isNot(contains('AbCdEfGhIjKl')));
      expect(line, isNot(contains(_email)));
    }
  }

  Finder confirmation() => find.text(
    trans('magic_starter.handoff.confirm_title', {'identity': _email}),
  );

  group('with no session', () {
    testWidgets('asks first, in the signed-out wording', (tester) async {
      arrange();

      await visit(tester, {'code': _code});

      expect(confirmation(), findsOneWidget);
      expect(
        find.text(
          trans('magic_starter.handoff.confirm_description_signed_out'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.handoff.confirm_description')),
        findsNothing,
      );
      auth.assertLoginCount(0);
      expect(MagicRouter.instance.currentPath, '/auth/handoff');
      expectNeverEchoed();
    });

    testWidgets('Continue signs in and opens the handed destination', (
      tester,
    ) async {
      arrange();
      await visit(tester, {'code': _code});

      await tester.tap(
        find.text(trans('magic_starter.handoff.continue_button')),
      );
      await tester.pumpAndSettle();

      expect(signOuts, 0);
      auth.assertLoginCount(1);
      expect(MagicRouter.instance.currentLocation, '/monitors/42');
      expect(find.text('monitor-page'), findsOneWidget);
      expectNeverEchoed();
    });

    testWidgets('Cancel opens the sign-in screen and revokes the token', (
      tester,
    ) async {
      arrange();
      await visit(tester, {'code': _code});

      await tester.tap(find.text(trans('magic_starter.handoff.cancel_button')));
      await tester.pumpAndSettle();

      auth.assertLoginCount(0);
      expect(MagicRouter.instance.currentLocation, '/auth/login');
      expect(server.recorded.last.$1.url, '/auth/logout');
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
    });

    testWidgets('signs in at once when the app turned the question off', (
      tester,
    ) async {
      Config.set('magic_starter.handoff.confirm_without_session', false);
      arrange();

      await visit(tester, {'code': _code});

      expect(confirmation(), findsNothing);
      auth.assertLoginCount(1);
      expect(MagicRouter.instance.currentLocation, '/monitors/42');
    });

    testWidgets('a two-factor answer opens the challenge after Continue', (
      tester,
    ) async {
      arrange(
        answer: Http.response({
          'two_factor': true,
          'two_factor_token': 'challenge-token',
          'data': {'next': '/monitors/42'},
        }),
      );

      await visit(tester, {'code': _code});

      expect(
        find.text(trans('magic_starter.handoff.confirm_title_unknown')),
        findsOneWidget,
      );
      await tester.tap(
        find.text(trans('magic_starter.handoff.continue_button')),
      );
      await tester.pumpAndSettle();

      auth.assertLoginCount(0);
      expect(MagicRouter.instance.currentPath, '/auth/two-factor-challenge');
      expect(MagicRouter.instance.pullIntendedUrl(), '/monitors/42');
    });

    testWidgets('a refused code opens the sign-in screen with one toast', (
      tester,
    ) async {
      arrange(
        answer: Http.response({
          'message': 'This sign-in link has expired.',
          'code': 'handoff_expired',
        }, 422),
      );

      await visit(tester, {'code': _code, 'next': '/teams'});

      auth.assertLoggedOut();
      expect(MagicRouter.instance.currentLocation, '/auth/login');
      expect(find.text(trans('magic_starter.handoff.expired')), findsOneWidget);
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
      expectNeverEchoed();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  group('over an open session', () {
    testWidgets('asks first and changes nothing until answered', (
      tester,
    ) async {
      arrange();
      signInBob();

      await visit(tester, {'code': _code});

      expect(confirmation(), findsOneWidget);
      expect(
        find.text(trans('magic_starter.handoff.confirm_description')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.handoff.continue_button')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.handoff.cancel_button')),
        findsOneWidget,
      );
      expect(signOuts, 0);
      auth.assertLoginCount(0);
      expect(MagicRouter.instance.currentPath, '/auth/handoff');
      expectNeverEchoed();
    });

    testWidgets('Continue swaps the account and opens the destination', (
      tester,
    ) async {
      arrange();
      signInBob();
      await visit(tester, {'code': _code});

      await tester.tap(
        find.text(trans('magic_starter.handoff.continue_button')),
      );
      await tester.pumpAndSettle();

      expect(signOuts, 1);
      auth.assertLoginCount(1);
      expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-ada');
      expect(MagicRouter.instance.currentLocation, '/monitors/42');
      expectNeverEchoed();
    });

    testWidgets('Cancel opens home with the session untouched', (tester) async {
      arrange();
      signInBob();
      await visit(tester, {'code': _code});

      await tester.tap(find.text(trans('magic_starter.handoff.cancel_button')));
      await tester.pumpAndSettle();

      expect(signOuts, 0);
      auth.assertLoginCount(0);
      expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-bob');
      expect(MagicRouter.instance.currentLocation, '/');
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
      expect(server.recorded.last.$1.url, '/auth/logout');
    });

    testWidgets('a refused code opens home with the session untouched', (
      tester,
    ) async {
      arrange(
        answer: Http.response({
          'message': 'This sign-in link has expired.',
          'code': 'handoff_expired',
        }, 422),
      );
      signInBob();

      await visit(tester, {'code': _code});

      expect(signOuts, 0);
      expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-bob');
      expect(MagicRouter.instance.currentLocation, '/');
      expectNeverEchoed();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  group('without a code', () {
    testWidgets('a signed-in visitor opens next', (tester) async {
      arrange();
      signInBob();

      await visit(tester, {'next': '/teams'});

      server.assertNothingSent();
      expect(MagicRouter.instance.currentLocation, '/teams');
    });

    testWidgets('a signed-out visitor signs in carrying next', (tester) async {
      arrange();

      await visit(tester, {'next': '/teams'});

      server.assertNothingSent();
      expect(MagicRouter.instance.currentLocation, '/auth/login?next=%2Fteams');
    });

    testWidgets('the signed-out route is configurable', (tester) async {
      Config.set('magic_starter.handoff.signed_out_route', '/auth/register');
      arrange();

      await visit(tester, {'next': '/teams'});

      expect(MagicRouter.instance.currentPath, '/auth/register');
    });

    testWidgets('an unsafe next is ignored', (tester) async {
      arrange();
      signInBob();

      await visit(tester, {'next': '//evil.example/x'});

      expect(MagicRouter.instance.currentLocation, '/');
    });

    testWidgets('a signed-in visitor with nothing opens home', (tester) async {
      arrange();
      signInBob();

      await visit(tester, {});

      expect(MagicRouter.instance.currentLocation, '/');
    });

    testWidgets('a signed-out visitor with nothing opens the sign-in screen', (
      tester,
    ) async {
      arrange();

      await visit(tester, {});

      server.assertNothingSent();
      expect(MagicRouter.instance.currentLocation, '/auth/login');
    });
  });
}
