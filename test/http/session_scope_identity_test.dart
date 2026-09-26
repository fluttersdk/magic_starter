import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Records every reset, standing in for a repository or controller whose rows
/// belong to one tenant.
class _RecordingHolder implements SessionScoped {
  int resets = 0;

  @override
  Future<void> resetForSession() async {
    resets++;
  }
}

void main() {
  // The provider's boot reads `WidgetsBinding.instance` for its primary colour
  // fallback, and every test here boots it for real.
  TestWidgetsFlutterBinding.ensureInitialized();

  final String? Function() coreIdentity = SessionScope.identity;

  late _RecordingHolder holder;
  MagicStarterTeam? currentTeam;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Magic.singleton('log', () => LogManager());

    holder = _RecordingHolder();
    SessionScope.detach();
    SessionScope.register(holder);
  });

  tearDown(() {
    SessionScope.detach();
    SessionScope.unregister(holder);
    SessionScope.identity = coreIdentity;
    Auth.unfake();
  });

  /// Boots the starter provider the way every starter app does, then points
  /// the resolver at [currentTeam] so a switch is a plain assignment.
  Future<void> bootProvider() async {
    final provider = MagicStarterServiceProvider(MagicApp.instance);
    provider.register();
    await provider.boot();

    MagicStarter.useTeamResolver(
      currentTeam: () => currentTeam,
      allTeams: () => [?currentTeam],
      onSwitch: (_) async {},
    );
  }

  MagicStarterAuthUser user(int id) =>
      MagicStarterAuthUser.fromMap({'id': id, 'name': 'User $id'});

  group('the session identity the starter declares', () {
    test(
      'includes the active team, so a switch by the same user resets',
      () async {
        Auth.fake();
        currentTeam = const MagicStarterTeam(id: 10, name: 'Alpha');
        await bootProvider();
        SessionScope.attach();

        await Auth.login({'token': 't'}, user(1));
        await pumpEventQueue();
        expect(holder.resets, 1);

        // The same user, another tenant: the core default (user id alone) reads
        // this as no change and would keep team 10's rows on screen.
        currentTeam = const MagicStarterTeam(id: 20, name: 'Beta');
        Auth.stateNotifier.value++;
        await pumpEventQueue();

        expect(SessionScope.identity(), '1:20');
        expect(holder.resets, 2);
      },
    );

    test('is null while nobody is signed in', () async {
      Auth.fake();
      await bootProvider();

      expect(SessionScope.identity(), isNull);
    });

    test('leaves attaching to the app', () async {
      Auth.fake();
      await bootProvider();

      // Attaching has to be the app's last auth listener, so booting the
      // provider must not do it on the app's behalf.
      expect(SessionScope.isAttached, isFalse);
    });
  });
}
