import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The package's shipped social copy, so the asserted copy is the copy a host
/// installs.
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

/// A guard serving one fixed user, which is all the dialog reads.
class _FakeGuard implements Guard {
  _FakeGuard(this._user);

  final Authenticatable _user;

  @override
  T? user<T extends Model>() => _user as T?;

  @override
  bool check() => true;

  @override
  bool get guest => false;

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A bridge whose `confirm` answers a numbered token per call and records
/// every call, so a test can tell a reused token from a fresh one.
class _FakeSocialAuth implements MagicStarterSocialAuth {
  final List<String> confirmCalls = [];
  Object? confirmFailure;

  /// When set, `confirm` stays pending until the test completes it.
  Completer<String>? confirmGate;

  @override
  List<String> providers() => const ['google', 'github'];

  @override
  String label(String provider) => provider == 'google' ? 'Google' : 'GitHub';

  @override
  Widget icon(String provider) => const SizedBox.square(dimension: 16);

  @override
  Future<String> confirm(String provider) async {
    confirmCalls.add(provider);
    final failure = confirmFailure;
    if (failure != null) throw failure;
    if (confirmGate != null) return confirmGate!.future;

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

MagicStarterAuthUser _user({
  bool twoFactor = false,
  List<Map<String, dynamic>> accounts = const [],
}) {
  return MagicStarterAuthUser.fromMap({
    'id': 1,
    'has_password': false,
    'two_factor_enabled': twoFactor,
    'social_accounts': accounts,
  });
}

Map<String, dynamic> _google({String? revokedAt}) => {
  'provider': 'google',
  'email_at_link': 'a@example.com',
  'created_at': '2026-01-01T00:00:00Z',
  'revoked_at': revokedAt,
};

void main() {
  late _FakeSocialAuth bridge;
  Map<String, String>? result;
  var closed = false;

  void signInAs(MagicStarterAuthUser user) {
    Auth.manager.forgetGuards();
    Auth.manager.extend('fake', (_) => _FakeGuard(user));
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
    setUpMagicStarterForTests();
    bridge = _FakeSocialAuth();
    MagicStarter.useSocialAuth(bridge);
    result = null;
    closed = false;
    Translator.instance.setLoader(const _ShippedCatalogueLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  Future<void> open(
    WidgetTester tester, {
    ValueListenable<List<String>?>? accepts,
    Future<String?> Function(Map<String, String> proof)? onProof,
  }) async {
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
                result = await MagicStarterStepUpDialog.show(
                  context,
                  accepts: accepts,
                  onProof: onProof,
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final providerRows = find.descendant(
    of: find.byType(MagicStarterStepUpDialog),
    matching: find.byType(MSButton),
  );

  group('MagicStarterStepUpDialog', () {
    testWidgets(
      'offers nothing but the sentence with no 2FA and no linked account',
      (tester) async {
        signInAs(_user());

        await open(tester);

        expect(find.text(trans('social.step_up_required')), findsOneWidget);
        expect(find.byType(WFormInput), findsNothing);
        expect(providerRows, findsNothing);
      },
    );

    testWidgets('asks for a code when 2FA is enabled and returns it', (
      tester,
    ) async {
      signInAs(_user(twoFactor: true));

      await open(tester);
      await tester.enterText(find.byType(EditableText), '123456');
      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, equals({'code': '123456'}));
    });

    testWidgets('lists one row per active linked account, not a revoked one', (
      tester,
    ) async {
      signInAs(
        _user(
          accounts: [
            _google(),
            {..._google(), 'provider': 'github', 'revoked_at': '2026-02-01'},
          ],
        ),
      );

      await open(tester);

      expect(find.text('Confirm with Google'), findsOneWidget);
      expect(find.text('Confirm with GitHub'), findsNothing);
      expect(providerRows, findsOneWidget);
      expect(find.byType(WFormInput), findsNothing);
    });

    testWidgets('a provider tap calls confirm at once and returns its token', (
      tester,
    ) async {
      signInAs(_user(accounts: [_google()]));

      await open(tester);
      await tester.tap(providerRows);

      // Before any frame is pumped: the popup has to open inside the tap.
      expect(bridge.confirmCalls, ['google']);

      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, equals({'confirmation_token': 'tok-1'}));
    });

    testWidgets('a refusal shows inline, keeps the dialog, and the next tap '
        'sends a new token', (tester) async {
      signInAs(_user(accounts: [_google()]));
      final sent = <Map<String, String>>[];

      await open(
        tester,
        onProof: (proof) async {
          sent.add(proof);

          return sent.length == 1 ? 'refused by the server' : null;
        },
      );
      await tester.tap(providerRows);
      await tester.pumpAndSettle();

      expect(closed, isFalse);
      expect(find.text('refused by the server'), findsOneWidget);

      await tester.tap(providerRows);
      await tester.pumpAndSettle();

      expect(sent, [
        {'confirmation_token': 'tok-1'},
        {'confirmation_token': 'tok-2'},
      ]);
      expect(closed, isTrue);
      expect(result, equals({'confirmation_token': 'tok-2'}));
    });

    testWidgets('a cancelled provider flow shows nothing and stays open', (
      tester,
    ) async {
      signInAs(_user(accounts: [_google()]));
      bridge.confirmFailure = const MagicStarterSocialException(
        cancelled: true,
      );

      await open(tester);
      await tester.tap(providerRows);
      await tester.pumpAndSettle();

      expect(closed, isFalse);
      expect(find.text(trans('errors.unexpected')), findsNothing);
      expect(providerRows, findsOneWidget);
    });

    testWidgets('a coded provider failure shows its catalogue sentence', (
      tester,
    ) async {
      signInAs(_user(accounts: [_google()]));
      bridge.confirmFailure = const MagicStarterSocialException(
        code: 'flow_expired',
        message: 'fallback',
      );

      await open(tester);
      await tester.tap(providerRows);
      await tester.pumpAndSettle();

      expect(closed, isFalse);
      expect(find.text(trans('social.flow_expired')), findsOneWidget);
      expect(find.text('fallback'), findsNothing);
    });

    testWidgets('accepts narrows the options to what the server takes', (
      tester,
    ) async {
      signInAs(_user(twoFactor: true, accounts: [_google()]));
      final accepts = ValueNotifier<List<String>?>(null);
      addTearDown(accepts.dispose);

      await open(tester, accepts: accepts);
      expect(find.byType(WFormInput), findsOneWidget);
      expect(providerRows, findsOneWidget);

      accepts.value = ['confirmation_token'];
      await tester.pumpAndSettle();

      expect(find.byType(WFormInput), findsNothing);
      expect(providerRows, findsOneWidget);
    });

    testWidgets('cancel stays available while a provider confirm is pending, '
        'and the late token is discarded', (tester) async {
      signInAs(_user(accounts: [_google()]));
      bridge.confirmGate = Completer<String>();
      var proofs = 0;

      await open(
        tester,
        onProof: (proof) async {
          proofs++;

          return null;
        },
      );
      await tester.tap(providerRows);
      await tester.pump();

      expect(bridge.confirmCalls, ['google']);

      await tester.tap(find.text('common.cancel'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, isNull);
      expect(find.byType(MagicStarterStepUpDialog), findsNothing);

      bridge.confirmGate!.complete('late-token');
      await tester.pumpAndSettle();

      expect(proofs, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancel closes with no proof', (tester) async {
      signInAs(_user(twoFactor: true));

      await open(tester);
      await tester.tap(find.text('common.cancel'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, isNull);
    });
  });
}
