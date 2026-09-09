import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/facades/magic_starter.dart';
import 'package:magic_starter/src/http/session_scope_sync.dart';
import 'package:magic_starter/src/http/session_scoped_controller.dart';
import 'package:magic_starter/src/magic_starter_manager.dart';
import 'package:magic_starter/src/models/magic_starter_auth_user.dart';
import 'package:magic_starter/src/models/magic_starter_team.dart';

// ---------------------------------------------------------------------------
// Mock Guard: the real auth surface the sync listens to
// ---------------------------------------------------------------------------

/// Minimal [Guard] whose [stateNotifier] bumps on login, logout and restore,
/// exactly like `BaseGuard` does in production.
class MockGuard implements Guard {
  Authenticatable? _user;
  final ValueNotifier<int> _stateNotifier = ValueNotifier<int>(0);

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  Future<String?> getToken() async => 'mock-token';

  @override
  Future<bool> hasToken() async => _user != null;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    _user = user;
    _stateNotifier.value++;
  }

  @override
  Future<void> logout() async {
    _user = null;
    _stateNotifier.value++;
  }

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {
    _stateNotifier.value++;
  }

  @override
  void setUser(Authenticatable user) => _user = user;

  @override
  ValueNotifier<int> get stateNotifier => _stateNotifier;

  @override
  T? user<T extends Model>() => _user as T?;
}

// ---------------------------------------------------------------------------
// Fake session-scoped controllers
// ---------------------------------------------------------------------------

/// Holds rows for whoever was authenticated when they were fetched.
///
/// [resetForSession] clears BEFORE it refetches, which is the whole contract:
/// with [failRefetch] on, the refetch throws after the clear and the rows must
/// stay empty rather than fall back to the previous session's data.
class FakeScopedController implements SessionScopedController {
  FakeScopedController({this.failRefetch = false});

  /// Whether the refetch leg throws after the cached rows are dropped.
  bool failRefetch;

  /// The rows currently on screen, tagged with the id they were fetched for.
  final List<String> rows = <String>[];

  /// How many times [resetForSession] ran.
  int resetCount = 0;

  @override
  Future<void> resetForSession() async {
    resetCount++;
    rows.clear();

    await Future<void>.delayed(Duration.zero);

    if (failRefetch) {
      throw StateError('refetch failed');
    }

    rows.add('rows-for-${Auth.id()}');
  }
}

/// Fails synchronously, before any await, to prove the loop is not aborted by
/// the first throwing controller.
class ThrowingScopedController implements SessionScopedController {
  int resetCount = 0;

  @override
  Future<void> resetForSession() {
    resetCount++;

    return Future<void>.error(StateError('boom'));
  }
}

/// A controller that does NOT implement the contract; it must never be touched.
class PlainController {
  int resetCount = 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGuard mockGuard;
  MagicStarterTeam? currentTeam;

  setUp(() {
    MagicApp.reset();
    Magic.flush();

    Magic.singleton('log', () => LogManager());
    Config.set('logging', {
      'default': 'console',
      'channels': {
        'console': {'driver': 'console', 'level': 'debug'},
      },
    });

    mockGuard = MockGuard();
    Magic.singleton('auth', () => AuthManager());
    Auth.manager.forgetGuards();
    Auth.manager.extend('mock', (_) => mockGuard);
    Config.set('auth.defaults.guard', 'mock');
    Config.set('auth.guards', {
      'mock': {'driver': 'mock'},
    });

    Magic.singleton('magic_starter', () => MagicStarterManager());

    currentTeam = null;
    MagicStarter.useTeamResolver(
      currentTeam: () => currentTeam,
      allTeams: () =>
          currentTeam == null ? <MagicStarterTeam>[] : [currentTeam!],
      onSwitch: (_) async {},
    );

    // SessionScopeSync keeps process-wide statics that neither MagicApp.reset()
    // nor Magic.flush() touch, so every test must start detached to stay
    // order-independent.
    SessionScopeSync.detach();
  });

  tearDown(() {
    SessionScopeSync.detach();
    Auth.manager.forgetGuards();
  });

  /// Signs [id] in with [teamId] active, the way `Auth.login` does in
  /// production: the guard bumps `stateNotifier` before any navigation.
  Future<void> loginAs(dynamic id, {dynamic teamId}) async {
    currentTeam = teamId == null ? null : MagicStarterTeam(id: teamId);

    await Auth.login({
      'token': 'token-$id',
    }, MagicStarterAuthUser.fromMap({'id': id, 'name': 'User $id'}));
  }

  /// Switches the active team for the signed-in user, the way
  /// `MagicStarterTeamController.switchTeam` does: set the team, then
  /// `Auth.restore()` bumps `stateNotifier`.
  Future<void> switchTeam(dynamic teamId) async {
    currentTeam = MagicStarterTeam(id: teamId);

    await Auth.restore();
  }

  group('SessionScopeSync', () {
    test('attaches and detaches its auth state listener', () {
      expect(SessionScopeSync.isAttached, isFalse);

      SessionScopeSync.attach();
      expect(SessionScopeSync.isAttached, isTrue);

      SessionScopeSync.detach();
      expect(SessionScopeSync.isAttached, isFalse);
    });

    test('does not reset the controllers registered at attach time', () async {
      await loginAs(1, teamId: 10);
      SessionScopeSync.attach();

      final FakeScopedController controller = Magic.put(FakeScopedController());
      await pumpEventQueue();

      expect(controller.resetCount, 0);
    });

    test('drops the previous tenant rows when another user logs in', () async {
      await loginAs(1, teamId: 10);
      SessionScopeSync.attach();

      final FakeScopedController controller = Magic.put(FakeScopedController());
      controller.rows.addAll(['rows-for-1']);

      await loginAs(2, teamId: 20);
      await pumpEventQueue();

      expect(controller.resetCount, 1);
      expect(controller.rows, ['rows-for-2']);
      expect(controller.rows, isNot(contains('rows-for-1')));
    });

    test(
      'leaves the screen empty when the refetch after the clear fails',
      () async {
        await loginAs(1, teamId: 10);
        SessionScopeSync.attach();

        final FakeScopedController controller = Magic.put(
          FakeScopedController(failRefetch: true),
        );
        controller.rows.addAll(['rows-for-1']);

        await loginAs(2, teamId: 20);
        await pumpEventQueue();

        // The defect this contract exists for: a non-destructive reload would
        // keep the previous tenant's rows on screen after a failed refetch.
        expect(controller.resetCount, 1);
        expect(controller.rows, isEmpty);
      },
    );

    test('resets when the same user switches team', () async {
      await loginAs(1, teamId: 10);
      SessionScopeSync.attach();

      final FakeScopedController controller = Magic.put(FakeScopedController());
      controller.rows.addAll(['rows-for-team-10']);

      await switchTeam(20);
      await pumpEventQueue();

      expect(controller.resetCount, 1);
      expect(controller.rows, isNot(contains('rows-for-team-10')));
    });

    test('does not reset on logout', () async {
      await loginAs(1, teamId: 10);
      SessionScopeSync.attach();

      final FakeScopedController controller = Magic.put(FakeScopedController());
      controller.rows.addAll(['rows-for-1']);

      await Auth.logout();
      await pumpEventQueue();

      // A reset from the login screen can only produce 401s; the stale rows
      // stay unreachable in memory until the next login clears them.
      expect(controller.resetCount, 0);
      expect(controller.rows, ['rows-for-1']);
    });

    test('resets when the same user signs back in after a logout', () async {
      await loginAs(1, teamId: 10);
      SessionScopeSync.attach();

      final FakeScopedController controller = Magic.put(FakeScopedController());
      controller.rows.addAll(['rows-for-1']);

      await Auth.logout();
      await loginAs(1, teamId: 10);
      await pumpEventQueue();

      expect(controller.resetCount, 1);
      expect(controller.rows, ['rows-for-1']);
    });

    test('does not reset twice for an unchanged identity', () async {
      SessionScopeSync.attach();

      final FakeScopedController controller = Magic.put(FakeScopedController());

      await loginAs(1, teamId: 10);
      await pumpEventQueue();
      expect(controller.resetCount, 1);

      // An incidental bump (a session restore that changes nothing) must not
      // stampede a second wave of refetches.
      await Auth.restore();
      await pumpEventQueue();

      expect(controller.resetCount, 1);
    });

    test('isolates a failing controller so the others still reset', () async {
      await loginAs(1, teamId: 10);
      SessionScopeSync.attach();

      // Registered first: if one throw aborted the loop, the fake below would
      // never reset and would keep user 1's rows.
      final ThrowingScopedController throwing = Magic.put(
        ThrowingScopedController(),
      );
      final FakeScopedController controller = Magic.put(FakeScopedController());
      controller.rows.addAll(['rows-for-1']);

      await loginAs(2, teamId: 20);
      await pumpEventQueue();

      expect(throwing.resetCount, 1);
      expect(controller.resetCount, 1);
      expect(controller.rows, ['rows-for-2']);
    });

    test('ignores controllers that are not session scoped', () async {
      await loginAs(1, teamId: 10);
      SessionScopeSync.attach();

      final PlainController plain = Magic.put(PlainController());

      await loginAs(2, teamId: 20);
      await pumpEventQueue();

      expect(plain.resetCount, 0);
    });

    test('stops resetting after detach', () async {
      await loginAs(1, teamId: 10);
      SessionScopeSync.attach();

      final FakeScopedController controller = Magic.put(FakeScopedController());

      SessionScopeSync.detach();
      await loginAs(2, teamId: 20);
      await pumpEventQueue();

      expect(controller.resetCount, 0);
    });

    test('a second attach does not double the reset', () async {
      await loginAs(1, teamId: 10);
      SessionScopeSync.attach();
      SessionScopeSync.attach();

      final FakeScopedController controller = Magic.put(FakeScopedController());

      await loginAs(2, teamId: 20);
      await pumpEventQueue();

      expect(controller.resetCount, 1);
    });

    test('resets on login when no team resolver is registered', () async {
      // Teams off: the user leg of the `<userId>:<teamId>` key still changes.
      MagicStarter.manager.teamResolver = null;

      await loginAs(1);
      SessionScopeSync.attach();

      final FakeScopedController controller = Magic.put(FakeScopedController());
      controller.rows.addAll(['rows-for-1']);

      await loginAs(2);
      await pumpEventQueue();

      expect(controller.resetCount, 1);
      expect(controller.rows, ['rows-for-2']);
    });
  });
}
