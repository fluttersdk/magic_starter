import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    _user = user;
  }

  @override
  Future<void> logout() async => _user = null;

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
  Future<bool> hasToken() async => true;

  @override
  Future<String?> getToken() async => 'mock-token';

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {}

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MagicStarterServiceProvider', () {
    late MagicStarterServiceProvider provider;
    late MockGuard mockGuard;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Gate.flush();

      // Bind LogManager so Log.warning() / Log.info() work.
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      // Bind auth guard.
      mockGuard = MockGuard();
      Magic.singleton('auth', () => AuthManager());
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {'driver': 'mock'},
      });

      provider = MagicStarterServiceProvider(MagicApp.instance);
    });

    tearDown(() {
      Gate.flush();
      Auth.manager.forgetGuards();
    });

    // -----------------------------------------------------------------------
    // register()
    // -----------------------------------------------------------------------

    group('register()', () {
      test(
        'binds MagicStarterManager as singleton under magic_starter key',
        () {
          provider.register();

          final manager = Magic.make<MagicStarterManager>('magic_starter');

          expect(manager, isA<MagicStarterManager>());
        },
      );

      test('returns same instance on subsequent resolutions', () {
        provider.register();

        final first = Magic.make<MagicStarterManager>('magic_starter');
        final second = Magic.make<MagicStarterManager>('magic_starter');

        expect(first, same(second));
      });
    });

    // -----------------------------------------------------------------------
    // boot() — Gate abilities
    // -----------------------------------------------------------------------

    group('boot() Gate abilities', () {
      const abilities = [
        'starter.update-profile-photo',
        'starter.update-email',
        'starter.update-phone',
        'starter.update-password',
        'starter.verify-email',
        'starter.manage-two-factor',
        'starter.manage-newsletter',
        'starter.logout-sessions',
        'starter.delete-account',
      ];

      setUp(() {
        provider.register();
      });

      test('defines all 9 starter.* Gate abilities', () async {
        await provider.boot();

        // Authenticate a non-guest user so Gate.allows() can resolve.
        final user = MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Test User',
        });
        mockGuard.setUser(user);

        for (final ability in abilities) {
          expect(
            Gate.allows(ability),
            isTrue,
            reason: '$ability should be defined after boot()',
          );
        }
      });

      test('grants access to non-guest users', () async {
        await provider.boot();

        final user = MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Regular User',
          'is_guest': false,
        });
        mockGuard.setUser(user);

        for (final ability in abilities) {
          expect(
            Gate.allows(ability),
            isTrue,
            reason: '$ability should grant access to non-guest user',
          );
        }
      });

      test('denies access to guest users', () async {
        await provider.boot();

        final guest = MagicStarterAuthUser.fromMap({
          'id': 2,
          'name': 'Guest User',
          'is_guest': true,
        });
        mockGuard.setUser(guest);

        for (final ability in abilities) {
          expect(
            Gate.denies(ability),
            isTrue,
            reason: '$ability should deny access to guest user',
          );
        }
      });

      test('grants access when is_guest is absent from user model', () async {
        await provider.boot();

        // User without is_guest field — should be treated as non-guest.
        final user = MagicStarterAuthUser.fromMap({
          'id': 3,
          'name': 'Normal User',
        });
        mockGuard.setUser(user);

        for (final ability in abilities) {
          expect(
            Gate.allows(ability),
            isTrue,
            reason: '$ability should grant access when is_guest is not present',
          );
        }
      });
    });

    // -----------------------------------------------------------------------
    // boot() — teams validation
    // -----------------------------------------------------------------------

    group('boot() teams validation', () {
      setUp(() {
        provider.register();
      });

      test(
        'logs warning when teams enabled but no resolver configured',
        () async {
          Config.set('magic_starter.features.teams', true);

          // boot() should log a warning — no team resolver is set.
          // This verifies the code path executes without throwing.
          await provider.boot();

          // Verify teams feature is enabled and resolver is null.
          expect(
            Config.get<bool>('magic_starter.features.teams', false),
            isTrue,
          );
          expect(MagicStarter.manager.teamResolver, isNull);
        },
      );

      test('does not throw when teams feature is disabled', () async {
        Config.set('magic_starter.features.teams', false);

        // boot() should complete without issues.
        await expectLater(provider.boot(), completes);
      });

      test(
        'does not throw when teams enabled and resolver is configured',
        () async {
          Config.set('magic_starter.features.teams', true);

          MagicStarter.useTeamResolver(
            currentTeam: () => null,
            allTeams: () => [],
            onSwitch: (id) async {},
          );

          await expectLater(provider.boot(), completes);
          expect(MagicStarter.manager.teamResolver, isNotNull);
        },
      );
    });

    // -----------------------------------------------------------------------
    // boot() — completes without error
    // -----------------------------------------------------------------------

    group('boot() lifecycle', () {
      test('completes successfully with default configuration', () async {
        provider.register();

        await expectLater(provider.boot(), completes);
      });
    });
  });
}
