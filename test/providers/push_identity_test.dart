import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';
import 'package:magic_starter/magic_starter.dart';

/// Minimal authenticated user for the fake auth manager, mirroring the
/// `_FakeUser` helper in `test/middleware/ensure_authenticated_test.dart`.
class _FakeUser extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['id', 'name'];
}

_FakeUser _fakeUser({Object id = 42}) {
  final user = _FakeUser();
  user.fill({'id': id, 'name': 'Alice'});
  user.exists = true;
  return user;
}

/// A guard that keeps answering `id()` after the session ends.
///
/// `BaseGuard` clears `_user` on logout, so `check()` and `id()` go null
/// together and either one alone would appear to cover a sign-out. Nothing in
/// the Guard CONTRACT requires that, and this guard is the shape that tells
/// the two apart: it is the only way to prove the signed-in check is doing
/// work rather than shadowing the id check beside it.
class _StaleIdGuard implements Guard {
  bool _signedIn = false;

  void signIn() {
    _signedIn = true;
    stateNotifier.value++;
  }

  void signOutKeepingTheId() {
    _signedIn = false;
    stateNotifier.value++;
  }

  @override
  final ValueNotifier<int> stateNotifier = ValueNotifier<int>(0);

  @override
  bool check() => _signedIn;

  @override
  bool get guest => !check();

  @override
  dynamic id() => 42;

  @override
  T? user<T extends Model>() => null;

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async =>
      signIn();

  @override
  Future<void> logout() async => signOutKeepingTheId();

  @override
  void setUser(Authenticatable user) => signIn();

  @override
  Future<bool> hasToken() async => _signedIn;

  @override
  Future<String?> getToken() async => _signedIn ? 'token' : null;

  @override
  Future<bool> refreshToken() async => false;

  @override
  Future<void> restore() async {}
}

/// A push driver that records the external id it was told to log in as.
///
/// The only way to tell the `onPushDriverAttached` subscription apart from the
/// immediate declaration beside it: both set the same intent, and only the
/// reconcile that follows a driver arriving reaches `login`. Deleting the
/// subscription left every other test here green, which is what this exists
/// to stop.
class _RecordingPushDriver extends PushDriver {
  String? loggedInAs;
  bool loggedOut = false;

  final _received = StreamController<PushNotificationEvent>.broadcast();
  final _clicked = StreamController<PushNotificationEvent>.broadcast();
  final _permission = StreamController<PushPermissionState>.broadcast();
  final _identity = StreamController<PushIdentityChange>.broadcast();

  @override
  String get name => 'recording';

  @override
  bool get isSupported => true;

  @override
  bool get isOptedIn => true;

  @override
  Future<PushPermissionState> permissionState() async =>
      PushPermissionState.authorized;

  @override
  Future<void> initialize(Map<String, dynamic> config) async {}

  @override
  Future<void> login(String externalId) async => loggedInAs = externalId;

  @override
  Future<void> logout() async {
    loggedOut = true;
    loggedInAs = null;
  }

  @override
  Future<String?> currentExternalId() async => loggedInAs;

  @override
  Future<String?> currentSubscriptionId() async => 'subscription';

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> optIn() async {}

  @override
  Future<void> optOut() async {}

  @override
  Future<void> setTags(Map<String, String> tags) async {}

  @override
  Future<void> removeTag(String key) async {}

  @override
  Stream<PushNotificationEvent> get onNotificationReceived => _received.stream;

  @override
  Stream<PushNotificationEvent> get onNotificationClicked => _clicked.stream;

  @override
  Stream<PushPermissionState> get onPermissionChanged => _permission.stream;

  @override
  Stream<PushIdentityChange> get onIdentityChanged => _identity.stream;
}

void main() {
  // The provider's boot reads `WidgetsBinding.instance` for its primary colour
  // fallback, and every test here boots it for real.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Vault.fake();

    // Both keys are set on EVERY test rather than only where they differ.
    // `Config.set` survives `Magic.flush()`, so a value one test writes is a
    // value the next one inherits: the prefix case below leaked `operator-`
    // into two later tests before this was explicit, and each read as a defect
    // in the code rather than in the arrangement.
    //
    // Opt in, because every starter feature defaults to off and this one is
    // the gate the declaration is behind.
    Config.set('magic_starter.features.notifications', true);
    Config.set('magic_starter.notifications.external_id_prefix', 'user_');

    // `NotificationManager` is a process-wide singleton with no reset
    // (a `static final` on `NotificationManager`), so the declared intent outlives the
    // container flush above and the next test asserts against the previous
    // one's session. This is the only public way to put it back to nobody.
    await Notify.logoutPush();
  });

  tearDown(() {
    Auth.unfake();
    Vault.unfake();
  });

  /// Boots the starter provider, which is what registers the declaration.
  ///
  /// Through the provider rather than a helper, for the same reason the
  /// intended-url test does it: booting the provider is what every starter app
  /// does, and the defect this covers was that nothing in the package declared
  /// an identity at all.
  Future<void> bootProvider() async {
    final provider = MagicStarterServiceProvider(MagicApp.instance);
    provider.register();
    await provider.boot();
  }

  group('the push identity a session declares', () {
    test(
      'is declared when a session begins, prefixed for the backend',
      () async {
        Auth.fake();
        await bootProvider();

        // Nothing has signed in yet, so nothing has been declared.
        expect(Notify.manager.pushIntent, isNull);

        await Auth.login({'token': 't'}, _fakeUser());
        await pumpEventQueue();

        // `user_` is what magic-starter-laravel's HasNotifications composes on
        // the other side; the two have to agree exactly.
        expect(Notify.manager.pushIntent, 'user_42');
      },
    );

    test('is declared for the session a cold boot restores', () async {
      // The ordinary launch for somebody already signed in, and the path no
      // call site inside the auth controller can see.
      //
      // Driven by bumping the notifier rather than by calling `Auth.restore()`,
      // and the distinction is load-bearing: the REAL restore ends in
      // `setUser(cachedUser)` (`base_guard.dart:315`) which bumps
      // (`base_guard.dart:99`), but the test double's restore is
      // `Future<void>.value()` (`magic/lib/src/testing/fake_auth_manager.dart:156`)
      // and bumps nothing at all. Calling it here would assert against the
      // double's silence and pass whatever this listener did. So the bump is
      // the contract under test, and the line above is the evidence the real
      // path produces one.
      Auth.fake(user: _fakeUser());
      await bootProvider();

      Auth.stateNotifier.value++;
      await pumpEventQueue();

      expect(Notify.manager.pushIntent, 'user_42');
    });

    test(
      'is declared when the session was restored BEFORE this provider boots',
      () async {
        // The ordinary cold boot, and the one every other test here misses by
        // bumping after `bootProvider()`. Providers boot in order and this one
        // goes last: magic_example ships Auth, then Notifications, then Starter,
        // every doc prescribes it, and artisan's installer appends to the end.
        // So `AuthServiceProvider.boot` has already awaited `Auth.restore()` and
        // bumped, and the driver has already attached on a broadcast stream that
        // replays nothing. Subscribing alone declared nothing at all.
        //
        // What hid it in production is a SECOND bump from the unawaited
        // `_syncUserFromApi()` inside restore, which is absent on a token with
        // no cached user, on a device with no network, and with no userEndpoint.
        Auth.fake(user: _fakeUser());
        Auth.stateNotifier.value++;
        await pumpEventQueue();

        // Nothing is listening yet, so nothing has been declared.
        expect(Notify.manager.pushIntent, isNull);

        await bootProvider();
        await pumpEventQueue();

        expect(Notify.manager.pushIntent, 'user_42');
      },
    );

    test(
      'reaches the driver when one attaches after this provider boots',
      () async {
        // The other half of the ordering, and the half the immediate
        // declaration cannot cover. `want` records an intent with no driver
        // present, so `pushIntent` looks right either way; only the reconcile
        // that follows a driver arriving pushes the id INTO the SDK.
        // `NotificationManager._attachPushDriver` announces and does not
        // reconcile on its own, so `login` here is the subscription's work
        // and nothing else's.
        Auth.fake(user: _fakeUser());
        await bootProvider();
        Auth.stateNotifier.value++;
        await pumpEventQueue();

        final driver = _RecordingPushDriver();
        Notify.manager.setPushDriver(driver);
        await pumpEventQueue();

        expect(driver.loggedInAs, 'user_42');
      },
    );

    test('carries a configured prefix instead of the default', () async {
      Config.set('magic_starter.notifications.external_id_prefix', 'operator-');
      Auth.fake();
      await bootProvider();

      await Auth.login({'token': 't'}, _fakeUser());
      await pumpEventQueue();

      expect(Notify.manager.pushIntent, 'operator-42');
    });

    test('falls back to the default when the prefix is blank', () async {
      // The two halves of one stack normalise this the same way or they
      // compose different ids. PHP's accessor maps a blank to `user_` and
      // trims; the Dart `??` did neither, because `Config.get` returns the
      // stored value whenever it is a String and `''` is one. An adopter
      // following both changelogs' "change one side and change the other"
      // with an empty value got `42` here and `user_42` there.
      for (final String blank in const ['', '   ']) {
        Config.set('magic_starter.notifications.external_id_prefix', blank);
        await Notify.logoutPush();
        Auth.unfake();
        Auth.fake();
        await bootProvider();

        await Auth.login({'token': 't'}, _fakeUser());
        await pumpEventQueue();

        expect(Notify.manager.pushIntent, 'user_42', reason: 'blank: "$blank"');
      }
    });

    test('trims a prefix written with surrounding space', () async {
      Config.set('magic_starter.notifications.external_id_prefix', ' staff_ ');
      Auth.fake();
      await bootProvider();

      await Auth.login({'token': 't'}, _fakeUser());
      await pumpEventQueue();

      expect(Notify.manager.pushIntent, 'staff_42');
    });

    test('is not declared while the notifications feature is off', () async {
      Config.set('magic_starter.features.notifications', false);
      Auth.fake();
      await bootProvider();

      await Auth.login({'token': 't'}, _fakeUser());
      await pumpEventQueue();

      expect(Notify.manager.pushIntent, isNull);
    });

    test('is released by a sign-out the auth controller never saw', () async {
      // Account deletion (`magic_starter_profile_controller.dart:193`) and a
      // failed token refresh (magic's `auth_interceptor.dart:77`) call
      // `Auth.logout()` bare, so `Notify.logoutPush()`'s single caller in the
      // auth controller never runs for either. The intent is persisted, so
      // without this the device stays subscribed as a deleted account across
      // restarts. An earlier version of this test asserted the opposite and
      // encoded the defect.
      Auth.fake(user: _fakeUser());
      await bootProvider();
      Auth.stateNotifier.value++;
      await pumpEventQueue();
      expect(Notify.manager.pushIntent, 'user_42');

      await Auth.logout();
      await pumpEventQueue();

      expect(Notify.manager.pushIntent, isNull);
    });

    test('stops the poller on those same sign-outs', () async {
      // Both halves, because the auth controller does both
      // (`magic_starter_auth_controller.dart:343-344`) and these paths reach
      // neither. Releasing the identity while leaving the poller running
      // swaps one silent leak for another: after an account deletion it keeps
      // issuing `GET /notifications` with a dead token and nothing watches
      // the 401 that comes back.
      Auth.fake(user: _fakeUser());
      await bootProvider();
      Auth.stateNotifier.value++;
      await pumpEventQueue();

      Notify.startPolling();
      expect(Notify.manager.isPolling, isTrue);

      await Auth.logout();
      await pumpEventQueue();

      expect(Notify.manager.isPolling, isFalse);
    });

    test(
      'is not declared for a guard that still answers id() after sign-out',
      () async {
        // The discriminating case. Against `BaseGuard` a sign-out nulls the user,
        // so `check()` and `id()` fall together and the id check alone appears to
        // cover it; removing the signed-in check left every other test here
        // green. A guard that keeps its id is what shows the check is load
        // bearing, and the Guard contract permits one.
        // Registered through the manager the way the auth controller tests do
        // it, because `Auth.stateNotifier` resolves `auth` as an AuthManager and
        // binding a bare Guard under that key throws inside the sibling listener
        // this provider also installs.
        final guard = _StaleIdGuard();
        Magic.singleton('auth', () => AuthManager());
        Auth.manager.forgetGuards();
        Auth.manager.extend('stale', (_) => guard);
        Config.set('auth.defaults.guard', 'stale');
        Config.set('auth.guards', {
          'stale': {'driver': 'stale'},
        });

        await bootProvider();

        guard.signIn();
        await pumpEventQueue();
        expect(Notify.manager.pushIntent, 'user_42');

        await Notify.logoutPush();
        guard.signOutKeepingTheId();
        await pumpEventQueue();

        expect(Notify.manager.pushIntent, isNull);
      },
    );

    test('survives a second boot against a re-bound auth guard', () async {
      // The failure mode a review caught on the sibling listener: a one-way
      // latch never clears, so a second boot leaves the subscription on a
      // notifier nobody bumps any more. Identity comparison is what fixes it,
      // and this is the test that can tell the two apart.
      Auth.fake();
      await bootProvider();

      Auth.unfake();
      Auth.fake();
      await bootProvider();

      await Auth.login({'token': 't'}, _fakeUser());
      await pumpEventQueue();

      expect(Notify.manager.pushIntent, 'user_42');
    });
  });
}
