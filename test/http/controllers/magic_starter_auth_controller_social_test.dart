import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The package's shipped social copy, so an assertion on rendered copy is an
/// assertion about what a host installs rather than a literal typed here.
class _ShippedCatalogueLoader implements TranslationLoader {
  const _ShippedCatalogueLoader();

  /// The stub's `social` section under the dotted keys `trans()` reads; the
  /// translator does not flatten a loader's nested maps.
  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final stub =
        jsonDecode(File('assets/stubs/install/en.stub').readAsStringSync())
            as Map<String, dynamic>;
    final social = stub['social'] as Map<String, dynamic>;

    return {
      for (final entry in social.entries) 'social.${entry.key}': entry.value,
    };
  }
}

/// A bridge that answers [signIn] with a scripted body or failure.
class _FakeSocialAuth implements MagicStarterSocialAuth {
  _FakeSocialAuth({this.body, this.failure, this.gate});

  /// When set, [signIn] stays pending until the test completes it.
  final Completer<Map<String, dynamic>>? gate;

  final Map<String, dynamic>? body;
  final MagicStarterSocialException? failure;
  final List<String> signInCalls = [];

  @override
  List<String> providers() => const ['google'];

  @override
  String label(String provider) => 'Google';

  @override
  Widget icon(String provider) => const SizedBox();

  @override
  Future<Map<String, dynamic>> signIn(String provider) async {
    signInCalls.add(provider);
    if (gate != null) return gate!.future;
    final failure = this.failure;
    if (failure != null) throw failure;

    return body!;
  }

  @override
  Future<Future<Map<String, dynamic>> Function()> beginConnect(
    String provider,
    Map<String, String> proof,
  ) => throw UnimplementedError();

  @override
  Future<String> confirm(String provider) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

void main() {
  late MagicStarterAuthController controller;

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Magic.singleton('log', () => LogManager());
    Config.set('logging', {
      'default': 'console',
      'channels': {
        'console': {'driver': 'console', 'level': 'debug'},
      },
    });
    setUpMagicStarterForTests();
    Auth.fake();
    Http.fake();
    Translator.instance.setLoader(const _ShippedCatalogueLoader());
    await Translator.instance.setLocale(const Locale('en'));
    controller = MagicStarterAuthController();
  });

  tearDown(() {
    controller.dispose();
    Auth.unfake();
    Http.unfake();
  });

  /// Mounts a router on the login page so navigation and toasts are real.
  ///
  /// [WindTheme] sits above the app because a toast is inserted into the
  /// Navigator's overlay, a sibling of the routed pages.
  Future<void> mountOnLogin(WidgetTester tester) async {
    MagicRoute.page('/', () => const Text('home'));
    MagicRoute.page(MagicStarterConfig.loginRoute(), () => const Text('login'));
    MagicRoute.page(
      MagicStarterConfig.twoFactorChallengeRoute(),
      () => const Text('challenge'),
    );
    MagicRouter.instance.setInitialLocation(MagicStarterConfig.loginRoute());

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp.router(
          routerConfig: MagicRouter.instance.routerConfig,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Lets the toast's auto-dismiss timer run out so no timer outlives a case.
  Future<void> flushToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  group('doSocialSignIn', () {
    test('names the provider while its flow is open, then clears it', () async {
      final gate = Completer<Map<String, dynamic>>();
      MagicStarter.useSocialAuth(_FakeSocialAuth(gate: gate));

      final pending = controller.doSocialSignIn('google');

      expect(controller.pendingSocialProvider, 'google');
      expect(controller.isLoading, isFalse);

      gate.completeError(const MagicStarterSocialException(cancelled: true));
      await pending;

      expect(controller.pendingSocialProvider, isNull);
    });

    testWidgets('signs in with the token and user the bridge returns', (
      tester,
    ) async {
      await mountOnLogin(tester);
      final bridge = _FakeSocialAuth(
        body: {
          'data': {
            'token': 'social-token',
            'user': {'id': 7, 'name': 'Ada', 'email': 'ada@example.com'},
          },
          'message': 'Login successful',
        },
      );
      MagicStarter.useSocialAuth(bridge);

      await controller.doSocialSignIn('google');
      await tester.pumpAndSettle();

      expect(bridge.signInCalls, ['google']);
      expect(Auth.check(), isTrue);
      expect(Auth.user<MagicStarterAuthUser>()?.email, 'ada@example.com');
      expect(controller.isSuccess, isTrue);
      expect(MagicRouter.instance.currentPath, MagicStarterConfig.homeRoute());
    });

    testWidgets('a 2FA answer opens the challenge with its token', (
      tester,
    ) async {
      await mountOnLogin(tester);
      MagicStarter.useSocialAuth(
        _FakeSocialAuth(body: {'two_factor': true, 'two_factor_token': 't'}),
      );

      await controller.doSocialSignIn('google');
      await tester.pumpAndSettle();

      expect(Auth.check(), isFalse);
      expect(
        MagicRouter.instance.currentPath,
        MagicStarterConfig.twoFactorChallengeRoute(),
      );
      expect(MagicRouter.instance.queryParameter('two_factor_token'), 't');
    });

    testWidgets('a cancelled flow shows nothing', (tester) async {
      await mountOnLogin(tester);
      MagicStarter.useSocialAuth(
        _FakeSocialAuth(
          failure: const MagicStarterSocialException(cancelled: true),
        ),
      );

      await controller.doSocialSignIn('google');
      await tester.pumpAndSettle();

      expect(controller.isError, isFalse);
      expect(controller.isLoading, isFalse);
      expect(Auth.check(), isFalse);
      expect(MagicRouter.instance.currentPath, MagicStarterConfig.loginRoute());
    });

    testWidgets('a coded refusal shows the catalogue sentence for the code', (
      tester,
    ) async {
      await mountOnLogin(tester);
      MagicStarter.useSocialAuth(
        _FakeSocialAuth(
          failure: const MagicStarterSocialException(
            code: 'social_email_taken',
            message: 'Server sentence.',
          ),
        ),
      );

      await controller.doSocialSignIn('google');
      await tester.pumpAndSettle();

      expect(controller.isError, isTrue);
      expect(
        controller.rxStatus.message,
        'An account with this email already exists. Sign in and link the '
        'provider from your profile.',
      );
    });

    testWidgets('a code the catalogue lacks falls back to the server message', (
      tester,
    ) async {
      await mountOnLogin(tester);
      MagicStarter.useSocialAuth(
        _FakeSocialAuth(
          failure: const MagicStarterSocialException(
            code: 'some_future_code',
            message: 'Server sentence.',
          ),
        ),
      );

      await controller.doSocialSignIn('google');
      await tester.pumpAndSettle();

      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, 'Server sentence.');
    });

    testWidgets('a cancelled deletion is announced on social sign-in', (
      tester,
    ) async {
      await mountOnLogin(tester);
      MagicStarter.useSocialAuth(
        _FakeSocialAuth(
          body: {
            'data': {
              'token': 'social-token',
              'user': {'id': 7},
              'deletion_cancelled': true,
            },
          },
        ),
      );

      await controller.doSocialSignIn('google');
      await tester.pump();

      expect(
        find.text('Account deletion cancelled. Your account is active again.'),
        findsOneWidget,
      );
      await flushToast(tester);
    });
  });

  group('the shared completion', () {
    testWidgets('doTwoFactorChallenge announces a cancelled deletion', (
      tester,
    ) async {
      await mountOnLogin(tester);
      Http.fake({
        '*/auth/two-factor-challenge': Http.response({
          'data': {
            'token': 'challenge-token',
            'user': {'id': 7},
            'deletion_cancelled': true,
          },
          'message':
              'Account deletion cancelled. Your account is active again.',
        }, 200),
      });

      await controller.doTwoFactorChallenge(
        twoFactorToken: 't',
        code: '123456',
      );
      await tester.pump();

      expect(Auth.check(), isTrue);
      expect(
        find.text('Account deletion cancelled. Your account is active again.'),
        findsOneWidget,
      );
      await flushToast(tester);
    });

    testWidgets('doLogin announces a cancelled deletion', (tester) async {
      await mountOnLogin(tester);
      Http.fake({
        '*/auth/login': Http.response({
          'data': {
            'token': 'password-token',
            'user': {'id': 7},
            'deletion_cancelled': true,
          },
        }, 200),
      });

      await controller.doLogin(email: 'ada@example.com', password: 'secret');
      await tester.pump();

      expect(Auth.check(), isTrue);
      expect(
        find.text('Account deletion cancelled. Your account is active again.'),
        findsOneWidget,
      );
      await flushToast(tester);
    });

    testWidgets('a sign-in that cancelled nothing shows no toast', (
      tester,
    ) async {
      await mountOnLogin(tester);
      Http.fake({
        '*/auth/login': Http.response({
          'data': {
            'token': 'password-token',
            'user': {'id': 7},
          },
        }, 200),
      });

      await controller.doLogin(email: 'ada@example.com', password: 'secret');
      await tester.pump();

      expect(
        find.text('Account deletion cancelled. Your account is active again.'),
        findsNothing,
      );
      await flushToast(tester);
    });
  });
}
