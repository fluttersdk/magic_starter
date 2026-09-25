import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Minimal authenticated user carrying a `locale` attribute, mirroring
/// `_FakeUser` in `test/providers/push_identity_test.dart`.
class _FakeUser extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['id', 'name', 'locale'];
}

_FakeUser _fakeUser({Object id = 1, String? locale}) {
  final user = _FakeUser();
  user.fill({'id': id, 'name': 'Alice', 'locale': ?locale});
  user.exists = true;
  return user;
}

/// Serves an empty catalogue for any locale, mirroring
/// `magic_starter_profile_controller_test.dart`'s `_StubLangLoader`: a locale
/// switch in these tests must succeed without shipping real copy for it.
class _StubLangLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async => <String, dynamic>{};
}

/// Serves an empty catalogue for any locale, but only once [completer]
/// completes: holds a [Lang.setLocale] call mid-flight for as long as a test
/// needs, mirroring a real asset catalogue that outlasts a couple of frames
/// (a real load is async, and one over 50 KB goes through `compute()`).
class _SlowLangLoader implements TranslationLoader {
  _SlowLangLoader(this.completer);

  final Completer<void> completer;

  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    await completer.future;
    return <String, dynamic>{};
  }
}

/// A guard whose `restore()` bumps the state notifier the way the real
/// `BaseGuard.setUser` does, and can hand back a different (updated) user.
///
/// The package's own [FakeAuthManager]'s guard deliberately does NOT bump on
/// `restore()` (right for the push-identity suite, wrong here, per that
/// suite's own comment at `push_identity_test.dart:337`): the profile-save
/// interaction this file tests only exists because a REAL restore bumps the
/// same notifier its own caller is about to read from again.
class _RestoringGuard implements Guard {
  Authenticatable? _user;

  /// The user `restore()` hands back, once set. Models a profile save: the
  /// server accepted the new locale, and a restore now serves it back.
  Authenticatable? userAfterRestore;

  @override
  final ValueNotifier<int> stateNotifier = ValueNotifier<int>(0);

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  T? user<T extends Model>() => _user as T?;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  void setUser(Authenticatable user) => _user = user;

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    _user = user;
    stateNotifier.value++;
  }

  @override
  Future<void> logout() async {
    _user = null;
    stateNotifier.value++;
  }

  @override
  Future<bool> hasToken() async => _user != null;

  @override
  Future<String?> getToken() async => _user != null ? 'token' : null;

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {
    if (userAfterRestore != null) _user = userAfterRestore;
    stateNotifier.value++;
  }
}

void main() {
  // The provider's boot reads `WidgetsBinding.instance` for its primary
  // colour fallback and the locale application's post-frame callback, and
  // every test here boots it for real.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Boots the starter provider, which is what registers both listeners
  /// under test. Through the provider rather than a helper, for the same
  /// reason `push_identity_test.dart` does it.
  Future<void> bootProvider() async {
    final provider = MagicStarterServiceProvider(MagicApp.instance);
    provider.register();
    await provider.boot();
  }

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();

    // Production always has this bound (`Magic.init` binds it before any app
    // provider boots), and this provider boots last. Without it, `Log.error`
    // in the code under test would throw a container exception instead of
    // logging, which is exactly what the "throwing onLogin" test exercises.
    Magic.singleton('log', () => LogManager());

    Translator.instance.setLoader(_StubLangLoader());
  });

  tearDown(() {
    Auth.unfake();
  });

  group('the onLogin hook', () {
    test('AuthLogin calls the registered onLogin hook once', () async {
      Auth.fake();
      await bootProvider();

      var callCount = 0;
      MagicStarter.useLogin(() async => callCount++);

      // Dispatched directly rather than via `Auth.login()`/the guard: the
      // worktree's override resolves `magic` from a sibling that already
      // dispatches `AuthLogin` from its fake guard, but this provider must
      // compile and behave correctly against magic master too, where that is
      // not guaranteed.
      await Event.dispatch(AuthLogin(_fakeUser()));
      await pumpEventQueue();

      expect(callCount, 1);
    });

    test('a throwing onLogin is logged, not rethrown', () async {
      Auth.fake();
      await bootProvider();

      MagicStarter.useLogin(() async => throw StateError('boom'));

      // The assertion is that this completes at all: a rethrow would
      // surface as an unhandled async error the test binding reports.
      await expectLater(Event.dispatch(AuthLogin(_fakeUser())), completes);
      await pumpEventQueue();
    });

    test('AuthRestored does not call onLogin', () async {
      Auth.fake();
      await bootProvider();

      var callCount = 0;
      MagicStarter.useLogin(() async => callCount++);

      await Event.dispatch(AuthRestored(_fakeUser()));
      await pumpEventQueue();

      expect(callCount, 0);
    });

    test('does nothing when no onLogin hook is registered', () async {
      Auth.fake();
      await bootProvider();

      await expectLater(Event.dispatch(AuthLogin(_fakeUser())), completes);
    });
  });

  group('applying a saved locale', () {
    testWidgets(
      'a signed-in user already carrying a different locale switches once '
      'boot reads it',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await Translator.instance.setLocale(const Locale('en'));

        Auth.fake(user: _fakeUser(locale: 'tr'));
        await bootProvider();

        await tester.pump();
        await tester.pumpAndSettle();

        expect(Lang.current.languageCode, equals('tr'));
      },
    );

    testWidgets(
      'a locale that arrives after boot, via a notifier bump, switches too',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await Translator.instance.setLocale(const Locale('en'));

        final fake = Auth.fake();
        await bootProvider();
        expect(Lang.current.languageCode, equals('en'));

        fake.guard().setUser(_fakeUser(locale: 'tr'));
        Auth.stateNotifier.value++;

        await tester.pump();
        await tester.pumpAndSettle();

        expect(Lang.current.languageCode, equals('tr'));
      },
    );

    testWidgets('the same locale as current causes no switch', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Translator.instance.setLocale(const Locale('en'));

      Auth.fake(user: _fakeUser(locale: 'en'));
      await bootProvider();

      await tester.pump();
      await tester.pumpAndSettle();

      expect(Lang.current.languageCode, equals('en'));
    });

    testWidgets('a signed-out session causes no switch', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Translator.instance.setLocale(const Locale('en'));

      Auth.fake();
      await bootProvider();

      await tester.pump();
      await tester.pumpAndSettle();

      expect(Lang.current.languageCode, equals('en'));
    });

    testWidgets('does nothing while the config toggle is off', (tester) async {
      Config.set('magic_starter.localization.apply_user_locale', false);
      await tester.pumpWidget(const SizedBox.shrink());
      await Translator.instance.setLocale(const Locale('en'));

      Auth.fake(user: _fakeUser(locale: 'tr'));
      await bootProvider();

      await tester.pump();
      await tester.pumpAndSettle();

      expect(Lang.current.languageCode, equals('en'));
    });

    testWidgets(
      'a profile save that restores a new locale issues exactly one switch',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await Translator.instance.setLocale(const Locale('en'));

        // A guard whose `restore()` genuinely bumps the notifier and hands
        // back a locale-updated user, the way `doUpdateProfile`'s real
        // `Auth.restore()` -> `_applySavedLanguage()` sequence does.
        final guard = _RestoringGuard()..setUser(_fakeUser(locale: 'en'));
        guard.userAfterRestore = _fakeUser(locale: 'tr');
        Magic.singleton('auth', () => AuthManager());
        Auth.manager.forgetGuards();
        Auth.manager.extend('restoring', (_) => guard);
        Config.set('auth.defaults.guard', 'restoring');
        Config.set('auth.guards', {
          'restoring': {'driver': 'restoring'},
        });

        await bootProvider();

        Magic.singleton('network', () => FakeNetworkDriver());
        final controller = MagicStarterProfileController();

        var switchCount = 0;
        Lang.addListener(() => switchCount++);

        final result = await controller.doUpdateProfile(
          name: 'Alice',
          email: 'alice@example.com',
          language: 'tr',
        );
        expect(result, isTrue);

        await tester.pump();
        await tester.pumpAndSettle();

        expect(Lang.current.languageCode, equals('tr'));
        expect(switchCount, equals(1));

        controller.dispose();
      },
    );

    testWidgets(
      'a slow catalogue load does not double-switch when a profile save '
      'lands in the same window as the restore listener',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await Translator.instance.setLocale(const Locale('en'));

        // Holds every `Lang.setLocale('tr')` call mid-flight until the test
        // completes it, past the couple of frames the old implementation
        // deferred by. A real catalogue load is exactly this: async, and
        // sometimes slower than a fixed number of frames.
        final completer = Completer<void>();
        Translator.instance.setLoader(_SlowLangLoader(completer));

        // Same wiring as the test above: a guard whose `restore()` bumps the
        // notifier `MagicStarterServiceProvider`'s listener is subscribed to
        // and hands back a locale-updated user, the way `doUpdateProfile`'s
        // real `Auth.restore()` -> `_applySavedLanguage()` sequence does.
        final guard = _RestoringGuard()..setUser(_fakeUser(locale: 'en'));
        guard.userAfterRestore = _fakeUser(locale: 'tr');
        Magic.singleton('auth', () => AuthManager());
        Auth.manager.forgetGuards();
        Auth.manager.extend('restoring', (_) => guard);
        Config.set('auth.defaults.guard', 'restoring');
        Config.set('auth.guards', {
          'restoring': {'driver': 'restoring'},
        });

        await bootProvider();

        Magic.singleton('network', () => FakeNetworkDriver());
        final controller = MagicStarterProfileController();

        var switchCount = 0;
        Lang.addListener(() => switchCount++);

        final result = await controller.doUpdateProfile(
          name: 'Alice',
          email: 'alice@example.com',
          language: 'tr',
        );
        expect(result, isTrue);

        // A few frames pass while the catalogue is still loading, past the
        // old two-frame defer window: nothing has switched yet either way.
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(switchCount, equals(0));

        completer.complete();
        await tester.pumpAndSettle();

        expect(Lang.current.languageCode, equals('tr'));
        expect(switchCount, equals(1));

        controller.dispose();
      },
    );
  });

  group('MagicStarterManager.applyLocale', () {
    // A fresh, unbound manager per test rather than `MagicStarter.manager`:
    // the facade falls back to a process-wide shared instance when nothing
    // is bound, and these tests care about one manager's own pending state.
    late MagicStarterManager manager;

    setUp(() => manager = MagicStarterManager());

    testWidgets('two calls to the same locale before a frame issue one '
        'switch', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Translator.instance.setLocale(const Locale('en'));

      var switchCount = 0;
      Lang.addListener(() => switchCount++);

      manager.applyLocale('tr');
      manager.applyLocale('tr');

      await tester.pump();
      await tester.pumpAndSettle();

      expect(Lang.current.languageCode, equals('tr'));
      expect(switchCount, equals(1));
    });

    testWidgets('a call before the frame ends supersedes the one before it', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Translator.instance.setLocale(const Locale('de'));

      var switchCount = 0;
      Lang.addListener(() => switchCount++);

      manager.applyLocale('tr');
      manager.applyLocale('en');

      await tester.pump();
      await tester.pumpAndSettle();

      // The superseded 'tr' callback finds a newer pending target and
      // backs off; only 'en' switches.
      expect(Lang.current.languageCode, equals('en'));
      expect(switchCount, equals(1));
    });

    testWidgets('reset() clears the pending target', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Translator.instance.setLocale(const Locale('en'));

      var switchCount = 0;
      Lang.addListener(() => switchCount++);

      manager.applyLocale('tr');
      manager.reset();

      await tester.pump();
      await tester.pumpAndSettle();

      // The callback still fires, but its pending target is gone, so it
      // finds itself superseded by nothing and backs off.
      expect(Lang.current.languageCode, equals('en'));
      expect(switchCount, equals(0));
    });

    testWidgets(
      'a call that arrives while an earlier switch is in flight lands once '
      'that switch settles, instead of being dropped',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await Translator.instance.setLocale(const Locale('en'));

        // Holds every catalogue load mid-flight, mirroring a real load that
        // outlasts a couple of frames; see `_SlowLangLoader`'s own doc.
        final completer = Completer<void>();
        Translator.instance.setLoader(_SlowLangLoader(completer));

        var switchCount = 0;
        Lang.addListener(() => switchCount++);

        manager.applyLocale('tr');
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // The 'tr' switch is now awaiting its catalogue load, so
        // `Lang.current` still reports 'en'. A caller that trusted it alone
        // here would read this as already-current and skip itself.
        manager.applyLocale('en');
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(switchCount, equals(0));

        completer.complete();
        await tester.pumpAndSettle();

        expect(Lang.current.languageCode, equals('en'));
        // Two real `Lang.setLocale` calls: the one 'tr' had already
        // committed to before 'en' arrived, and the chased 'en' that runs
        // once 'tr' settles.
        expect(switchCount, equals(2));
      },
    );

    testWidgets(
      'a target reverted and restored while its switch is in flight leaves '
      'nothing pending behind',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await Translator.instance.setLocale(const Locale('en'));

        final completer = Completer<void>();
        Translator.instance.setLoader(_SlowLangLoader(completer));

        manager.applyLocale('tr');
        await tester.pump();
        await tester.pump();

        // 'tr' is loading: revert to 'en', then restore 'tr' before it lands.
        manager.applyLocale('en');
        manager.applyLocale('tr');
        await tester.pump();

        completer.complete();
        await tester.pumpAndSettle();
        expect(Lang.current.languageCode, equals('tr'));

        // Something else moves the app back to 'en'; asking for 'tr' again
        // must switch rather than read a stale pending 'tr' as done.
        await Translator.instance.setLocale(const Locale('en'));
        manager.applyLocale('tr');
        await tester.pumpAndSettle();

        expect(Lang.current.languageCode, equals('tr'));
      },
    );
  });
}
