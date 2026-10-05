import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class _ShippedCatalogueLoader implements TranslationLoader {
  const _ShippedCatalogueLoader();

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

class _FakeGuard implements Guard {
  _FakeGuard(this._user);

  final Authenticatable _user;
  bool restoreCalled = false;

  @override
  T? user<T extends Model>() => _user as T?;

  @override
  bool check() => true;

  @override
  bool get guest => false;

  @override
  Future<void> restore() async => restoreCalled = true;

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocialAuth implements MagicStarterSocialAuth {
  final List<String> confirmCalls = [];

  @override
  List<String> providers() => const ['google'];

  @override
  String label(String provider) => 'Google';

  @override
  Widget icon(String provider) => const SizedBox.square(dimension: 16);

  @override
  Future<String> confirm(String provider) async {
    confirmCalls.add(provider);

    return 'tok-${confirmCalls.length}';
  }

  @override
  Future<Map<String, dynamic>> signIn(String provider) =>
      throw UnimplementedError();

  @override
  Future<Future<Map<String, dynamic>> Function()> beginConnect(
    String provider,
    Map<String, String> proof,
  ) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

/// Records each request body and answers from a queue.
class _MockNetworkDriver implements NetworkDriver {
  final List<dynamic> bodies = [];
  final List<MagicResponse> queue = [];

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    bodies.add(data);

    return queue.isEmpty
        ? MagicResponse(data: {}, statusCode: 200)
        : queue.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _stepUpRefusal() => {
  'message': 'Please confirm your identity to continue.',
  'code': 'step_up_required',
  'accepts': ['confirmation_token'],
};

void main() {
  late _FakeSocialAuth bridge;
  late _MockNetworkDriver driver;
  late MagicStarterProfileController controller;
  Map<String, String>? proof;
  var finished = false;

  void signInAs(Map<String, dynamic> attributes) {
    Auth.manager.forgetGuards();
    Auth.manager.extend(
      'fake',
      (_) => _FakeGuard(MagicStarterAuthUser.fromMap({'id': 1, ...attributes})),
    );
    Config.set('auth.defaults.guard', 'fake');
    Config.set('auth.guards', {
      'fake': {'driver': 'fake'},
    });
  }

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('log', () => LogManager());
    Magic.singleton('auth', () => AuthManager());
    driver = _MockNetworkDriver();
    Magic.singleton('network', () => driver);
    setUpMagicStarterForTests();
    Config.set('magic_starter.features.sessions', true);
    bridge = _FakeSocialAuth();
    MagicStarter.useSocialAuth(bridge);
    controller = MagicStarterProfileController();
    proof = null;
    finished = false;
    Translator.instance.setLoader(const _ShippedCatalogueLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    controller.dispose();
    Auth.manager.forgetGuards();
  });

  Future<void> mount(
    WidgetTester tester,
    Future<Map<String, String>?> Function(BuildContext context) run,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            WindTheme(data: WindThemeData(), child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                proof = await run(context);
                finished = true;
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  final providerRow = find.descendant(
    of: find.byType(MagicStarterStepUpDialog),
    matching: find.byType(MSButton),
  );

  group('confirmIdentity', () {
    testWidgets('a user with a password is asked for it and sends {password}', (
      tester,
    ) async {
      signInAs({'has_password': true});

      await mount(tester, (context) => confirmIdentity(context));

      expect(find.byType(MagicStarterPasswordConfirmDialog), findsOneWidget);
      expect(find.byType(MagicStarterStepUpDialog), findsNothing);

      await tester.enterText(find.byType(EditableText), 'secret-123');
      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      expect(proof, equals({'password': 'secret-123'}));
    });

    testWidgets('an account that predates has_password is a password user', (
      tester,
    ) async {
      signInAs({});

      await mount(tester, (context) => confirmIdentity(context));

      expect(find.byType(MagicStarterPasswordConfirmDialog), findsOneWidget);
    });

    testWidgets('a guest sends no proof and sees no dialog', (tester) async {
      signInAs({'has_password': false, 'is_guest': true});

      await mount(tester, (context) => confirmIdentity(context));

      expect(find.byType(MagicStarterPasswordConfirmDialog), findsNothing);
      expect(find.byType(MagicStarterStepUpDialog), findsNothing);
      expect(finished, isTrue);
      expect(proof, equals(<String, String>{}));
    });

    testWidgets('a password-less 2FA user sends {code}', (tester) async {
      signInAs({'has_password': false, 'two_factor_enabled': true});

      await mount(tester, (context) => confirmIdentity(context));
      await tester.enterText(find.byType(EditableText), '654321');
      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      expect(proof, equals({'code': '654321'}));
    });

    testWidgets('a password-less user with Google sends the bridge token', (
      tester,
    ) async {
      signInAs({
        'has_password': false,
        'social_accounts': [
          {'provider': 'google', 'revoked_at': null},
        ],
      });

      await mount(tester, (context) => confirmIdentity(context));
      await tester.tap(providerRow);
      await tester.pumpAndSettle();

      expect(bridge.confirmCalls, ['google']);
      expect(proof, equals({'confirmation_token': 'tok-1'}));
    });

    testWidgets('cancelling the dialog answers null', (tester) async {
      signInAs({'has_password': true});

      await mount(tester, (context) => confirmIdentity(context));
      await tester.tap(find.text('common.cancel'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
      expect(proof, isNull);
    });
  });

  group('confirmAndRun', () {
    testWidgets('a password user posts {password} through the action', (
      tester,
    ) async {
      signInAs({'has_password': true});
      driver.queue.add(MagicResponse(data: {}, statusCode: 200));
      var ok = false;

      await mount(tester, (context) async {
        ok = await confirmAndRun(
          context,
          controller,
          action: (proof) => controller.doRevokeOtherSessions(proof: proof),
        );

        return null;
      });
      await tester.enterText(find.byType(EditableText), 'secret-123');
      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      expect(ok, isTrue);
      expect(
        driver.bodies.single,
        equals({'_method': 'DELETE', 'password': 'secret-123'}),
      );
    });

    testWidgets('a guest runs the action with no proof and no dialog', (
      tester,
    ) async {
      signInAs({'has_password': false, 'is_guest': true});
      var ok = false;

      await mount(tester, (context) async {
        ok = await confirmAndRun(
          context,
          controller,
          action: (proof) => controller.doRevokeOtherSessions(proof: proof),
        );

        return null;
      });

      expect(ok, isTrue);
      expect(find.byType(MagicStarterStepUpDialog), findsNothing);
      expect(driver.bodies.single, equals({'_method': 'DELETE'}));
    });

    testWidgets('after step_up_required the second attempt mints a new token', (
      tester,
    ) async {
      signInAs({
        'has_password': false,
        'two_factor_enabled': true,
        'social_accounts': [
          {'provider': 'google', 'revoked_at': null},
        ],
      });
      driver.queue
        ..add(MagicResponse(data: _stepUpRefusal(), statusCode: 422))
        ..add(MagicResponse(data: {}, statusCode: 200));
      var ok = false;

      await mount(tester, (context) async {
        ok = await confirmAndRun(
          context,
          controller,
          action: (proof) => controller.doRevokeOtherSessions(proof: proof),
        );

        return null;
      });
      expect(find.byType(WFormInput), findsOneWidget);

      await tester.tap(providerRow);
      await tester.pumpAndSettle();

      // The refusal stays inline, and the code field is gone: the server only
      // takes a confirmation token.
      expect(ok, isFalse);
      expect(find.byType(MagicStarterStepUpDialog), findsOneWidget);
      expect(find.text(trans('social.step_up_required')), findsWidgets);
      expect(find.byType(WFormInput), findsNothing);

      await tester.tap(providerRow);
      await tester.pumpAndSettle();

      expect(ok, isTrue);
      expect(bridge.confirmCalls, ['google', 'google']);
      expect(driver.bodies, [
        {'_method': 'DELETE', 'confirmation_token': 'tok-1'},
        {'_method': 'DELETE', 'confirmation_token': 'tok-2'},
      ]);
    });

    testWidgets('a wrong password shows inline and the retry sends a new one', (
      tester,
    ) async {
      signInAs({'has_password': true});
      driver.queue
        ..add(
          MagicResponse(
            data: {
              'message': 'Incorrect password',
              'errors': {
                'password': ['The password is incorrect.'],
              },
            },
            statusCode: 422,
          ),
        )
        ..add(MagicResponse(data: {}, statusCode: 200));
      var ok = false;

      await mount(tester, (context) async {
        ok = await confirmAndRun(
          context,
          controller,
          action: (proof) => controller.doRevokeOtherSessions(proof: proof),
        );

        return null;
      });
      await tester.enterText(find.byType(EditableText), 'wrong');
      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      expect(ok, isFalse);
      expect(find.byType(MagicStarterPasswordConfirmDialog), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'right');
      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      expect(ok, isTrue);
      expect(driver.bodies, [
        {'_method': 'DELETE', 'password': 'wrong'},
        {'_method': 'DELETE', 'password': 'right'},
      ]);
    });

    testWidgets('a refusal no new proof can fix closes and keeps its error', (
      tester,
    ) async {
      signInAs({'has_password': true});
      driver.queue.add(
        MagicResponse(
          data: {'message': 'Owns teams', 'code': 'owns_shared_teams'},
          statusCode: 422,
        ),
      );
      var ok = true;

      await mount(tester, (context) async {
        ok = await confirmAndRun(
          context,
          controller,
          action: (proof) => controller.doDeleteAccount(proof: proof),
        );

        return null;
      });
      await tester.enterText(find.byType(EditableText), 'secret-123');
      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      expect(ok, isFalse);
      expect(find.byType(MagicStarterPasswordConfirmDialog), findsNothing);
      expect(controller.rxStatus.message, trans('social.owns_shared_teams'));
      expect(driver.bodies, hasLength(1));
    });

    testWidgets('a 422 on the new password closes and keeps the field error', (
      tester,
    ) async {
      signInAs({'has_password': false, 'two_factor_enabled': true});
      driver.queue.add(
        MagicResponse(
          data: {
            'message': 'The password is too short.',
            'errors': {
              'password': ['The password must be at least 8 characters.'],
            },
          },
          statusCode: 422,
        ),
      );
      var ok = true;

      await mount(tester, (context) async {
        ok = await confirmAndRun(
          context,
          controller,
          action: (proof) => controller.doSetPassword(
            password: 'short',
            passwordConfirmation: 'short',
            proof: proof,
          ),
        );

        return null;
      });
      await tester.enterText(find.byType(EditableText), '654321');
      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      expect(ok, isFalse);
      expect(find.byType(MagicStarterStepUpDialog), findsNothing);
      expect(
        controller.getError('password'),
        'The password must be at least 8 characters.',
      );
      expect(driver.bodies, hasLength(1));
    });
  });
}
