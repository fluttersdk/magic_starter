import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class _FakeUser extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['id', 'name', 'is_guest'];
}

_FakeUser _user(Object id, {bool guest = false}) {
  final _FakeUser user = _FakeUser();
  user.fill({'id': id, 'name': 'Viewer', 'is_guest': guest});
  user.exists = true;
  return user;
}

/// A vault whose deletes land a turn of the event loop later, the way a real
/// keychain call does. The in-memory fake deletes synchronously, which would
/// let an UNAWAITED forget pass the isolation test by accident.
class _SlowVault extends FakeVaultService {
  @override
  Future<void> remove(String key) async {
    await Future<void>.delayed(Duration.zero);
    await super.remove(key);
  }
}

void main() {
  late FakeNetworkDriver claimApi;
  late FakeLogManager logs;
  late List<GuestClaimOutcome> reported;

  /// Stubs the claim endpoint on the injected driver.
  FakeNetworkDriver stubClaim(FutureOr<MagicResponse> Function() answer) {
    claimApi = FakeNetworkDriver(stubs: (MagicRequest request) => answer());
    MagicStarterGuestClaim.instance = MagicStarterGuestClaim(
      driver: () => claimApi,
    );

    return claimApi;
  }

  MagicResponse status(int code) => MagicResponse(
    data: <String, dynamic>{
      'data': <String, dynamic>{'user': <String, dynamic>{}, 'claimed': true},
    },
    statusCode: code,
  );

  /// Registers the provider's listeners, which is what wires the claim.
  void registerProvider() {
    MagicStarterServiceProvider(MagicApp.instance).register();
    MagicStarter.useGuestClaimed((GuestClaimOutcome outcome) async {
      reported.add(outcome);
    });
  }

  /// Signs in as a guest, which records the guest token and id.
  Future<void> signInAsGuest() async {
    await Auth.login(<String, dynamic>{
      'token': 'guest-token',
    }, _user('g-1', guest: true));
  }

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Vault.fake();
    logs = Log.fake();
    Auth.fake();
    Config.set('magic_starter.features.guest_auth', true);
    MagicStarterGuestClaim.instance = null;
    reported = <GuestClaimOutcome>[];
    stubClaim(() => status(200));
  });

  tearDown(() {
    Auth.unfake();
    MagicStarterGuestClaim.instance = null;
  });

  test('a guest sign-in records the guest token and id', () async {
    registerProvider();

    await signInAsGuest();

    expect(await Vault.get(MagicStarterGuestClaim.tokenKey), 'guest-token');
    expect(await Vault.get(MagicStarterGuestClaim.userKey), 'g-1');
    claimApi.assertNothingSent();
  });

  test('an integer id is recorded in its string form', () async {
    registerProvider();

    await Auth.login(<String, dynamic>{
      'token': 'guest-token',
    }, _user(7, guest: true));

    expect(await Vault.get(MagicStarterGuestClaim.userKey), '7');
  });

  test(
    'a later sign-in claims once, with the guest token and the target bearer',
    () async {
      registerProvider();
      await signInAsGuest();

      await Auth.login(<String, dynamic>{
        'token': 'target-token',
      }, _user('u-2'));
      await pumpEventQueue();

      final MagicRequest request = claimApi.recorded.single.$1;

      expect(request.method, 'POST');
      expect(request.url, MagicStarterGuestClaim.path);
      expect(request.data, <String, dynamic>{'guest_token': 'guest-token'});
      expect(request.headers['Authorization'], 'Bearer target-token');
      expect(await Vault.get(MagicStarterGuestClaim.tokenKey), isNull);
      expect(await Vault.get(MagicStarterGuestClaim.userKey), isNull);
      expect(reported, <GuestClaimOutcome>[GuestClaimOutcome.claimed]);
    },
  );

  test(
    'a 422 is terminal: the record goes and the hook hears refused',
    () async {
      stubClaim(() => status(422));
      registerProvider();
      await signInAsGuest();

      await Auth.login(<String, dynamic>{
        'token': 'target-token',
      }, _user('u-2'));
      await pumpEventQueue();

      expect(await Vault.get(MagicStarterGuestClaim.tokenKey), isNull);
      expect(reported, <GuestClaimOutcome>[GuestClaimOutcome.refused]);
    },
  );

  test(
    'a 404 is terminal: the record goes and the hook hears refused',
    () async {
      // A backend without the claim route answers 404 on every attempt, and a
      // kept record would post the guest's live token on every restore forever.
      stubClaim(() => status(404));
      registerProvider();
      await signInAsGuest();

      await Auth.login(<String, dynamic>{
        'token': 'target-token',
      }, _user('u-2'));
      await pumpEventQueue();

      claimApi.assertSentCount(1);
      expect(await Vault.get(MagicStarterGuestClaim.tokenKey), isNull);
      expect(await Vault.get(MagicStarterGuestClaim.userKey), isNull);
      expect(reported, <GuestClaimOutcome>[GuestClaimOutcome.refused]);
    },
  );

  test(
    'a claim answering after its session ended leaves the next guest record',
    () async {
      final Completer<MagicResponse> held = Completer<MagicResponse>();
      stubClaim(() => held.future);
      registerProvider();
      await signInAsGuest();
      await Auth.login(<String, dynamic>{'token': 'a-token'}, _user('u-a'));
      await pumpEventQueue();

      await Auth.logout();
      await Auth.login(<String, dynamic>{
        'token': 'guest-2-token',
      }, _user('g-2', guest: true));

      held.complete(status(200));
      await pumpEventQueue();

      claimApi.assertSentCount(1);
      expect(await Vault.get(MagicStarterGuestClaim.tokenKey), 'guest-2-token');
      expect(await Vault.get(MagicStarterGuestClaim.userKey), 'g-2');
      expect(reported, isEmpty);
    },
  );

  test(
    'a sign-in after a sign-out does not inherit the claim in flight',
    () async {
      final Completer<MagicResponse> held = Completer<MagicResponse>();
      stubClaim(() => held.future);
      registerProvider();
      await signInAsGuest();
      await Auth.login(<String, dynamic>{'token': 'a-token'}, _user('u-a'));
      await pumpEventQueue();
      final Future<GuestClaimOutcome> claimOfA = MagicStarterGuestClaim.instance
          .claimIfPending();

      await Auth.logout();
      await Auth.login(<String, dynamic>{'token': 'b-token'}, _user('u-b'));
      final Future<GuestClaimOutcome> claimOfB = MagicStarterGuestClaim.instance
          .claimIfPending();

      expect(identical(claimOfA, claimOfB), isFalse);

      held.complete(status(200));

      expect(await claimOfB, GuestClaimOutcome.none);
      expect(await claimOfA, GuestClaimOutcome.none);
      await pumpEventQueue();
      claimApi.assertSentCount(1);
      expect(reported, isEmpty);
    },
  );

  test(
    'an answer does not delete a record written over the one it posted',
    () async {
      final Completer<MagicResponse> held = Completer<MagicResponse>();
      stubClaim(() => held.future);
      await Vault.put(MagicStarterGuestClaim.tokenKey, 'guest-token');
      await Vault.put(MagicStarterGuestClaim.userKey, 'g-1');
      await Auth.login(<String, dynamic>{'token': 'a-token'}, _user('u-a'));

      final Future<GuestClaimOutcome> claim = MagicStarterGuestClaim.instance
          .claimIfPending();
      await pumpEventQueue();
      await Vault.put(MagicStarterGuestClaim.tokenKey, 'guest-2-token');
      await Vault.put(MagicStarterGuestClaim.userKey, 'g-2');

      held.complete(status(200));

      expect(await claim, GuestClaimOutcome.claimed);
      expect(await Vault.get(MagicStarterGuestClaim.tokenKey), 'guest-2-token');
      expect(await Vault.get(MagicStarterGuestClaim.userKey), 'g-2');
    },
  );

  test('a keychain that refuses to forget is logged as an error', () async {
    Vault.fake(<String, String>{
      MagicStarterGuestClaim.tokenKey: 'guest-token',
      MagicStarterGuestClaim.userKey: 'g-1',
    }).throwOnRemove(MagicVaultException('locked'));

    await MagicStarterGuestClaim.forget();

    expect(
      logs.entries.where((FakeLogEntry entry) => entry.level == 'error'),
      hasLength(1),
    );
  });

  test('a 500 keeps the record and the hook is not called', () async {
    stubClaim(() => status(500));
    registerProvider();
    await signInAsGuest();

    await Auth.login(<String, dynamic>{'token': 'target-token'}, _user('u-2'));
    await pumpEventQueue();

    claimApi.assertSentCount(1);
    expect(await Vault.get(MagicStarterGuestClaim.tokenKey), 'guest-token');
    expect(await Vault.get(MagicStarterGuestClaim.userKey), 'g-1');
    expect(reported, isEmpty);
  });

  test(
    'the promoted guest itself posts nothing and reports promoted',
    () async {
      registerProvider();
      await signInAsGuest();

      await Auth.login(<String, dynamic>{'token': 'same-token'}, _user('g-1'));
      await pumpEventQueue();

      claimApi.assertNothingSent();
      expect(await Vault.get(MagicStarterGuestClaim.tokenKey), isNull);
      expect(reported, <GuestClaimOutcome>[GuestClaimOutcome.promoted]);
    },
  );

  test('a restore of a real account claims too', () async {
    registerProvider();
    await signInAsGuest();

    final _FakeUser target = _user('u-2');
    await Auth.login(<String, dynamic>{'token': 'target-token'}, target);
    await pumpEventQueue();
    claimApi.recorded.clear();

    await Vault.put(MagicStarterGuestClaim.tokenKey, 'guest-token');
    await Vault.put(MagicStarterGuestClaim.userKey, 'g-1');

    await Event.dispatch(AuthRestored(target));
    await pumpEventQueue();

    claimApi.assertSentCount(1);
    expect(reported, <GuestClaimOutcome>[
      GuestClaimOutcome.claimed,
      GuestClaimOutcome.claimed,
    ]);
  });

  test(
    'a sign-out that is followed at once by another sign-in claims nothing',
    () async {
      // The previous viewer's record must be gone before the next person on the
      // device can sign in, or their account claims the previous viewer's rows.
      Magic.app.setInstance('vault', _SlowVault());
      registerProvider();
      await signInAsGuest();

      await Auth.logout();
      await Auth.login(<String, dynamic>{'token': 'b-token'}, _user('user-b'));
      await pumpEventQueue();

      claimApi.assertNothingSent();
      expect(await Vault.get(MagicStarterGuestClaim.tokenKey), isNull);
      expect(await Vault.get(MagicStarterGuestClaim.userKey), isNull);
      expect(reported, isEmpty);
    },
  );

  test('concurrent callers share one claim and one outcome', () async {
    final Completer<MagicResponse> held = Completer<MagicResponse>();
    stubClaim(() => held.future);
    await Vault.put(MagicStarterGuestClaim.tokenKey, 'guest-token');
    await Vault.put(MagicStarterGuestClaim.userKey, 'g-1');
    await Auth.login(<String, dynamic>{'token': 'target-token'}, _user('u-2'));

    final Future<GuestClaimOutcome> first = MagicStarterGuestClaim.instance
        .claimIfPending();
    final Future<GuestClaimOutcome> second = MagicStarterGuestClaim.instance
        .claimIfPending();

    expect(identical(first, second), isTrue);

    held.complete(status(200));

    expect(await first, GuestClaimOutcome.claimed);
    expect(await second, GuestClaimOutcome.claimed);
    claimApi.assertSentCount(1);
  });

  test('a sign-in and a restore during one claim report it once', () async {
    final Completer<MagicResponse> held = Completer<MagicResponse>();
    stubClaim(() => held.future);
    registerProvider();
    await signInAsGuest();

    final _FakeUser target = _user('u-2');
    await Auth.login(<String, dynamic>{'token': 'target-token'}, target);
    await Event.dispatch(AuthRestored(target));

    held.complete(status(200));
    await pumpEventQueue();

    claimApi.assertSentCount(1);
    expect(reported, <GuestClaimOutcome>[GuestClaimOutcome.claimed]);
  });

  test('Auth.login returns before a held claim answers', () async {
    final Completer<MagicResponse> held = Completer<MagicResponse>();
    stubClaim(() => held.future);
    registerProvider();
    await signInAsGuest();

    bool signedIn = false;
    unawaited(
      Auth.login(<String, dynamic>{
        'token': 'target-token',
      }, _user('u-2')).then((_) => signedIn = true),
    );
    await pumpEventQueue();

    expect(signedIn, isTrue);
    expect(reported, isEmpty);

    held.complete(status(200));
    await pumpEventQueue();

    expect(reported, <GuestClaimOutcome>[GuestClaimOutcome.claimed]);
  });

  test(
    'a signed-out device and a device with no record claim nothing',
    () async {
      expect(
        await MagicStarterGuestClaim.instance.claimIfPending(),
        GuestClaimOutcome.none,
      );

      await Auth.login(<String, dynamic>{
        'token': 'target-token',
      }, _user('u-2'));

      expect(
        await MagicStarterGuestClaim.instance.claimIfPending(),
        GuestClaimOutcome.none,
      );
      claimApi.assertNothingSent();
    },
  );

  test('a session that is still the guest claims nothing', () async {
    await signInAsGuest();
    await Vault.put(MagicStarterGuestClaim.tokenKey, 'guest-token');
    await Vault.put(MagicStarterGuestClaim.userKey, 'g-1');

    expect(
      await MagicStarterGuestClaim.instance.claimIfPending(),
      GuestClaimOutcome.none,
    );
    claimApi.assertNothingSent();
    expect(await Vault.get(MagicStarterGuestClaim.tokenKey), 'guest-token');
  });

  test(
    'a keychain that refuses the read is logged and settles nothing',
    () async {
      Vault.fake().throwOnGet(MagicVaultException('locked'));
      await Auth.login(<String, dynamic>{
        'token': 'target-token',
      }, _user('u-2'));

      expect(
        await MagicStarterGuestClaim.instance.claimIfPending(),
        GuestClaimOutcome.none,
      );
      claimApi.assertNothingSent();
    },
  );

  test('with the guest-auth feature off, the listeners do nothing', () async {
    Config.set('magic_starter.features.guest_auth', false);
    registerProvider();
    await signInAsGuest();

    expect(await Vault.get(MagicStarterGuestClaim.tokenKey), isNull);

    await Vault.put(MagicStarterGuestClaim.tokenKey, 'guest-token');
    await Vault.put(MagicStarterGuestClaim.userKey, 'g-1');
    await Auth.login(<String, dynamic>{'token': 'target-token'}, _user('u-2'));
    await Auth.logout();
    await pumpEventQueue();

    claimApi.assertNothingSent();
    expect(await Vault.get(MagicStarterGuestClaim.tokenKey), 'guest-token');
    expect(reported, isEmpty);
  });

  test('bootstrap takes onGuestClaimed, and reset() clears it', () {
    MagicStarter.bootstrap(
      userFactory: (Map<String, dynamic> data) => _FakeUser()..fill(data),
      onLogout: () async {},
      locales: <String, String>{'en': 'English'},
      onGuestClaimed: (GuestClaimOutcome outcome) async {},
    );

    expect(MagicStarter.manager.onGuestClaimed, isNotNull);

    MagicStarter.manager.reset();

    expect(MagicStarter.manager.onGuestClaimed, isNull);
  });
}
