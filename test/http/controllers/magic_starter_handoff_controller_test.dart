import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The package's shipped English `magic_starter.handoff` copy under the dotted
/// keys `trans()` reads, so the assertion is about what a host installs.
class _ShippedHandoffLoader implements TranslationLoader {
  const _ShippedHandoffLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final Map<String, dynamic> stub = jsonDecode(
      File('assets/stubs/install/en.stub').readAsStringSync(),
    ) as Map<String, dynamic>;
    final Map<String, dynamic> handoff =
        (stub['magic_starter'] as Map<String, dynamic>)['handoff']
            as Map<String, dynamic>;

    return {
      for (final MapEntry<String, dynamic> entry in handoff.entries)
        'magic_starter.handoff.${entry.key}': entry.value,
    };
  }
}

/// The one-time code a landing page hands over.
const String _code = 'hnd_Q2xhaW1Db2RlRm9yVGhlVGVzdA';

/// The session token the exchange answers with.
const String _token = '42|AbCdEfGhIjKlMnOpQrStUvWxYz0123456789abcd';

/// The handed account's email: shown on the confirmation, logged nowhere.
const String _email = 'ada@example.com';

/// The answer `POST /auth/handoff/exchange` gives for a valid code.
Map<String, dynamic> _session({Object? next = '/monitors/42'}) {
  return {
    'message': 'Signed in.',
    'data': {
      'token': _token,
      'user': {'id': 'user-ada', 'name': 'Ada', 'email': _email},
      'next': next,
    },
  };
}

/// The answer for a valid code whose account has two-factor on.
Map<String, dynamic> _challenge() {
  return {
    'two_factor': true,
    'two_factor_token': 'challenge-token',
    'data': {'next': '/monitors/42'},
  };
}

/// The one failure shape the exchange has.
MagicResponse _expired() {
  return Http.response({
    'message': 'This sign-in link has expired.',
    'code': 'handoff_expired',
  }, 422);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthManager auth;
  late FakeLogManager log;
  late FakeNetworkDriver server;
  late MagicStarterHandoffController controller;
  late int signOuts;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    setUpMagicStarterForTests();
    log = Log.fake();
    auth = Auth.fake();
    signOuts = 0;
    MagicStarter.manager.beforeLogout(() async => signOuts++);
  });

  tearDown(() {
    MagicRouter.instance.pullIntendedUrl();
    Auth.unfake();
    Log.unfake();
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  /// Answers every exchange with [answer] (or throws [error]) through a
  /// driver of the controller's own, the seam the exchange goes out on.
  void arrange({MagicResponse? answer, Object? error}) {
    server = FakeNetworkDriver(
      stubs: (MagicRequest request) {
        if (error != null) throw error;

        return answer ?? Http.response(_session());
      },
    );
    controller = MagicStarterHandoffController(driver: () => server);
    Magic.put<MagicStarterHandoffController>(controller);
  }

  /// Signs Bob in before the visit.
  void signInBob() {
    auth = Auth.fake(
      user: MagicStarter.createUser({
        'id': 'user-bob',
        'name': 'Bob',
        'email': 'bob@example.com',
      }),
    );
  }

  /// Fails when the code, the token or the email reached any log line.
  void expectNothingLogged() {
    for (final FakeLogEntry entry in log.entries) {
      final String line = '${entry.message} ${entry.context}';
      expect(line, isNot(contains(_code)));
      expect(line, isNot(contains('AbCdEfGhIjKl')));
      expect(line, isNot(contains(_email)));
    }
  }

  group('exchange without a session, by default', () {
    test('asks first: nobody is signed in before Continue', () async {
      arrange();

      await controller.handOff(code: _code);

      expect(MagicStarterConfig.handoffConfirmsWithoutSession(), isTrue);
      expect(controller.isConfirming, isTrue);
      expect(controller.confirmingAs, _email);
      auth.assertLoginCount(0);
      auth.assertLoggedOut();
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
      expectNothingLogged();
    });

    test(
      'Continue signs in as the handed account, signing nobody out',
      () async {
        arrange();
        await controller.handOff(code: _code);

        await controller.confirm();

        expect(signOuts, 0);
        auth.assertLoginCount(1);
        expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-ada');
        expect(MagicRouter.instance.pullIntendedUrl(), '/monitors/42');
        expectNothingLogged();
      },
    );

    test('Cancel signs nobody in and revokes the handed token', () async {
      arrange();
      await controller.handOff(code: _code);

      controller.cancel();
      await pumpEventQueue();

      auth.assertLoginCount(0);
      expect(controller.isConfirming, isFalse);
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
      final MagicRequest revoke = server.recorded.last.$1;
      expect(revoke.method, 'POST');
      expect(revoke.url, '/auth/logout');
      expect(revoke.headers['Authorization'], 'Bearer $_token');
      expectNothingLogged();
    });

    test('a two-factor answer is confirmed before the challenge', () async {
      arrange(answer: Http.response(_challenge()));

      await controller.handOff(code: _code);

      expect(controller.isConfirming, isTrue);
      expect(controller.confirmingAs, isNull);

      await controller.confirm();

      auth.assertLoginCount(0);
      expect(MagicRouter.instance.pullIntendedUrl(), '/monitors/42');
    });

    test('a declined challenge revokes nothing: it carries no token', () async {
      arrange(answer: Http.response(_challenge()));
      await controller.handOff(code: _code);

      controller.cancel();
      await pumpEventQueue();

      server.assertSentCount(1);
    });
  });

  group('exchange without a session, confirmation turned off', () {
    setUp(() {
      Config.set('magic_starter.handoff.confirm_without_session', false);
    });

    test('posts the code alone and signs in once', () async {
      arrange();

      await controller.handOff(code: _code);

      server.assertSentCount(1);
      final MagicRequest request = server.recorded.single.$1;
      expect(request.method, 'POST');
      expect(request.url, '/auth/handoff/exchange');
      expect(request.data, {'code': _code});
      auth.assertLoginCount(1);
      expect(await Auth.getToken(), _token);
      expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-ada');
      expect(MagicRouter.instance.pullIntendedUrl(), '/monitors/42');
      expectNothingLogged();
    });

    test('the server next wins over the query next', () async {
      arrange();

      await controller.handOff(code: _code, next: '/teams');

      expect(MagicRouter.instance.pullIntendedUrl(), '/monitors/42');
    });

    test('the query next is not used when the server names none', () async {
      arrange(answer: Http.response(_session(next: null)));

      await controller.handOff(code: _code, next: '/teams');

      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
    });

    test('an unsafe server next is not replaced by the query next', () async {
      arrange(answer: Http.response(_session(next: '//evil.example')));

      await controller.handOff(code: _code, next: '/teams');

      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
    });

    test('no next at all records no intended url', () async {
      arrange(answer: Http.response(_session(next: null)));

      await controller.handOff(code: _code, next: 'https://evil.example');

      auth.assertLoginCount(1);
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
    });

    test('a two-factor answer opens no session and keeps next', () async {
      arrange(answer: Http.response(_challenge()));

      await controller.handOff(code: _code);

      auth.assertLoginCount(0);
      auth.assertLoggedOut();
      expect(MagicRouter.instance.pullIntendedUrl(), '/monitors/42');
    });

    test('a refused code signs nobody in and records nothing', () async {
      arrange(answer: _expired());

      await controller.handOff(code: _code, next: '/teams');

      auth.assertLoginCount(0);
      auth.assertLoggedOut();
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
      expectNothingLogged();
    });

    test('a transport failure signs nobody in', () async {
      arrange(error: Exception('connection reset for $_code'));

      await controller.handOff(code: _code);

      auth.assertLoginCount(0);
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
      expectNothingLogged();
    });

    test(
      'a 200 that is neither a session nor a challenge is a failure',
      () async {
        arrange(answer: Http.response({'data': <String, dynamic>{}}));

        await controller.handOff(code: _code);

        auth.assertLoginCount(0);
        expect(controller.isConfirming, isFalse);
      },
    );

    test('the exchange does not ride the Http facade', () async {
      // The facade's driver carries the app's interceptors: magic's auth
      // interceptor (a 401 there starts its refresh-or-logout ladder) and any
      // devtools recorder that keeps response bodies, the token included.
      final FakeNetworkDriver facade = Http.fake();
      Config.set('network.drivers.api', {
        'base_url': 'http://127.0.0.1:1',
        'timeout': 2000,
      });
      controller = MagicStarterHandoffController();

      await controller.handOff(code: _code);

      facade.assertNothingSent();
      auth.assertLoginCount(0);
      Http.unfake();
    });

    test('a blank code sends nothing', () async {
      arrange();

      await controller.handOff(code: '');

      server.assertNothingSent();
      auth.assertLoginCount(0);
    });
  });

  group('exchange over an open session', () {
    test('asks first: nothing signs out or in before Continue', () async {
      arrange();
      signInBob();

      await controller.handOff(code: _code);

      expect(controller.isConfirming, isTrue);
      expect(controller.confirmingAs, _email);
      expect(signOuts, 0);
      auth.assertLoginCount(0);
      expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-bob');
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
      expectNothingLogged();
    });

    test('names the account by its name when it has no email', () async {
      final Map<String, dynamic> body = _session();
      (body['data'] as Map<String, dynamic>)['user'] = {
        'id': 'user-ada',
        'name': 'Ada',
      };
      arrange(answer: Http.response(body));
      signInBob();

      await controller.handOff(code: _code);

      expect(controller.confirmingAs, 'Ada');
    });

    test(
      'Continue signs the session out, then in as the handed account',
      () async {
        arrange();
        signInBob();
        await controller.handOff(code: _code);

        await controller.confirm();

        expect(signOuts, 1);
        auth.assertLoginCount(1);
        expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-ada');
        expect(controller.isConfirming, isFalse);
        expect(MagicRouter.instance.pullIntendedUrl(), '/monitors/42');
        expectNothingLogged();
      },
    );

    test('Cancel keeps the session and drops the answer', () async {
      arrange();
      signInBob();
      await controller.handOff(code: _code);

      controller.cancel();
      await controller.confirm();
      await pumpEventQueue();

      expect(signOuts, 0);
      auth.assertLoginCount(0);
      expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-bob');
      expect(controller.isConfirming, isFalse);
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
      // The handed token is revoked with its own bearer; the open session's
      // credential is never involved.
      final MagicRequest revoke = server.recorded.last.$1;
      expect(revoke.url, '/auth/logout');
      expect(revoke.headers['Authorization'], 'Bearer $_token');
      expect(server.recorded, hasLength(2));
    });

    test('leaving the screen revokes the handed token, once', () async {
      arrange();
      signInBob();
      await controller.handOff(code: _code);

      controller.forget();
      controller.forget();
      await pumpEventQueue();

      expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-bob');
      expect(
        server.recorded.where((entry) => entry.$1.url == '/auth/logout'),
        hasLength(1),
      );
    });

    test('a refused revoke is logged without the token', () async {
      server = FakeNetworkDriver(
        stubs: (MagicRequest request) => request.url == '/auth/logout'
            ? Http.response({'message': 'Unauthenticated.'}, 401)
            : Http.response(_session()),
      );
      controller = MagicStarterHandoffController(driver: () => server);
      signInBob();
      await controller.handOff(code: _code);

      controller.cancel();
      await pumpEventQueue();

      expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-bob');
      expectNothingLogged();
    });

    test('a two-factor answer is confirmed before the challenge', () async {
      arrange(answer: Http.response(_challenge()));
      signInBob();

      await controller.handOff(code: _code);

      expect(controller.isConfirming, isTrue);
      expect(controller.confirmingAs, isNull);
      expect(signOuts, 0);

      await controller.confirm();

      expect(signOuts, 1);
      auth.assertLoginCount(0);
      expect(MagicRouter.instance.pullIntendedUrl(), '/monitors/42');
    });

    test('a refused code leaves the session untouched', () async {
      arrange(answer: _expired());
      signInBob();

      await controller.handOff(code: _code);

      expect(controller.isConfirming, isFalse);
      expect(signOuts, 0);
      auth.assertLoginCount(0);
      expect(Auth.user<Authenticatable>()?.authIdentifier, 'user-bob');
      expectNothingLogged();
    });

    testWidgets('a refused code says so once, without telling why', (
      tester,
    ) async {
      Translator.instance.setLoader(const _ShippedHandoffLoader());
      await Translator.instance.setLocale(const Locale('en'));
      MagicRoute.page('/', () => const Text('home'));
      MagicRoute.page(
        MagicStarterConfig.loginRoute(),
        () => const Text('login'),
      );
      MagicRouter.instance.setInitialLocation('/');
      await tester.pumpWidget(
        WindTheme(
          data: WindThemeData(),
          child: MaterialApp.router(
            routerConfig: MagicRouter.instance.routerConfig,
          ),
        ),
      );
      await tester.pumpAndSettle();
      arrange(answer: _expired());
      signInBob();

      await controller.handOff(code: _code);
      await tester.pump();

      expect(
        find.text('This sign-in link has expired or was already used.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    test('an answer landing after the screen left is dropped', () async {
      final ValueNotifier<int> released = ValueNotifier<int>(0);
      server = FakeNetworkDriver(
        stubs: (MagicRequest request) async {
          await Future<void>.delayed(Duration.zero);
          released.value++;

          return Http.response(_session());
        },
      );
      controller = MagicStarterHandoffController(driver: () => server);
      signInBob();

      final Future<void> pending = controller.handOff(code: _code);
      controller.forget();
      await pending;
      await pumpEventQueue();

      expect(released.value, 2);
      expect(controller.isConfirming, isFalse);
      auth.assertLoginCount(0);
      // The dropped answer's token exists on the server, so it is revoked.
      expect(server.recorded.last.$1.url, '/auth/logout');
    });

    test('a new user drops a confirmation still waiting', () async {
      arrange();
      signInBob();
      await controller.handOff(code: _code);

      auth = Auth.fake(
        user: MagicStarter.createUser({
          'id': 'user-carol',
          'name': 'Carol',
          'email': 'carol@example.com',
        }),
      );
      await controller.resetForSession();
      await pumpEventQueue();

      expect(controller.isConfirming, isFalse);
      expect(server.recorded.last.$1.url, '/auth/logout');
    });

    test('a reset that keeps the signed-in user (a team switch) leaves the '
        'confirmation waiting', () async {
      // The claim behind the code moves the claimant's current team, and the
      // session scope resets on a team switch as well as on another user.
      arrange();
      signInBob();
      await controller.handOff(code: _code);

      await controller.resetForSession();
      await pumpEventQueue();

      expect(controller.isConfirming, isTrue);
      server.assertSentCount(1);
    });

    test(
      'a reset that keeps the user does not drop an exchange in flight',
      () async {
        final Completer<MagicResponse> answer = Completer<MagicResponse>();
        server = FakeNetworkDriver(
          stubs: (MagicRequest request) => answer.future,
        );
        controller = MagicStarterHandoffController(driver: () => server);
        Magic.put<MagicStarterHandoffController>(controller);
        signInBob();

        final Future<void> pending = controller.handOff(code: _code);
        await pumpEventQueue();

        await controller.resetForSession();
        answer.complete(Http.response(_session()));
        await pending;

        expect(controller.isConfirming, isTrue);
        server.assertSentCount(1);
      },
    );

    test(
      'Continue revokes nothing: the handed token is the new session',
      () async {
        arrange();
        signInBob();
        await controller.handOff(code: _code);

        await controller.confirm();
        await pumpEventQueue();

        server.assertSentCount(1);
      },
    );
  });

  group('holding a handoff', () {
    // The app remounts when its boot sync changed the user (`Magic.reload()`),
    // and a remount runs the screen again over a code the server has already
    // spent. The starter's reload listener asks this before it reloads.
    test('from the moment the exchange goes out', () async {
      final Completer<MagicResponse> answer = Completer<MagicResponse>();
      server = FakeNetworkDriver(
        stubs: (MagicRequest request) => answer.future,
      );
      controller = MagicStarterHandoffController(driver: () => server);
      Magic.put<MagicStarterHandoffController>(controller);

      expect(controller.holdsHandoff, isFalse);

      final Future<void> pending = controller.handOff(code: _code);
      await pumpEventQueue();

      expect(controller.holdsHandoff, isTrue);

      answer.complete(Http.response(_session()));
      await pending;
    });

    test('while the confirmation waits, until Continue', () async {
      arrange();
      signInBob();
      await controller.handOff(code: _code);

      expect(controller.holdsHandoff, isTrue);

      await controller.confirm();

      expect(controller.holdsHandoff, isFalse);
    });

    test('through the sign-out and sign-in Continue confirmed', () async {
      arrange();
      signInBob();
      await controller.handOff(code: _code);

      bool? heldDuringSignOut;
      MagicStarter.manager.beforeLogout(() async {
        heldDuringSignOut = controller.holdsHandoff;
      });

      await controller.confirm();

      expect(heldDuringSignOut, isTrue);
      expect(controller.holdsHandoff, isFalse);
    });

    test('until Cancel', () async {
      arrange();
      signInBob();
      await controller.handOff(code: _code);

      controller.cancel();
      await pumpEventQueue();

      expect(controller.holdsHandoff, isFalse);
    });

    test('until the screen leaves', () async {
      arrange();
      await controller.handOff(code: _code);

      controller.forget();
      await pumpEventQueue();

      expect(controller.holdsHandoff, isFalse);
    });

    test('not past a refused exchange', () async {
      arrange(answer: _expired());

      await controller.handOff(code: _code);

      expect(controller.holdsHandoff, isFalse);
    });

    test('not past an exchange that failed to reach the server', () async {
      arrange(error: StateError('offline'));

      await controller.handOff(code: _code);

      expect(controller.holdsHandoff, isFalse);
    });

    test('not when only a `next` is carried', () async {
      arrange();

      await controller.handOff(next: '/monitors/42');

      expect(controller.holdsHandoff, isFalse);
    });
  });
}
