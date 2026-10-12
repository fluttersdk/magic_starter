import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  // The provider's boot reads `WidgetsBinding.instance` for its primary colour
  // fallback, and every test here boots it for real.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLogManager log;

  /// Boots the starter provider, which is what registers the revoke hook.
  Future<void> bootProvider() async {
    final provider = MagicStarterServiceProvider(MagicApp.instance);
    provider.register();
    await provider.boot();
  }

  /// Signs in through the fake guard so it holds a token to revoke.
  Future<void> signIn() {
    return Auth.login({
      'token': 'account-token',
    }, MagicStarterAuthUser.fromMap({'id': 42, 'name': 'Alice'}));
  }

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    log = Log.fake();
    Config.set('magic_starter.features.notifications', false);
    Auth.fake();
  });

  tearDown(() {
    Auth.unfake();
    Http.unfake();
    Log.unfake();
  });

  group('the logout revoke hook', () {
    test('POSTs auth/logout while a token is held', () async {
      await bootProvider();
      await signIn();
      final fake = Http.fake();

      await MagicStarter.manager.runBeforeLogoutHooks();

      fake.assertSentCount(1);
      fake.assertSent(
        (MagicRequest request) =>
            request.method == 'POST' && request.url == '/auth/logout',
      );
    });

    test('sends nothing when no token is held', () async {
      await bootProvider();
      final fake = Http.fake();

      await MagicStarter.manager.runBeforeLogoutHooks();

      fake.assertNothingSent();
    });

    test('is registered once across two boots', () async {
      await bootProvider();
      await bootProvider();
      await signIn();
      final fake = Http.fake();

      await MagicStarter.manager.runBeforeLogoutHooks();

      fake.assertSentCount(1);
    });

    test('a refused revoke is logged and the sign-out goes on', () async {
      await bootProvider();
      await signIn();
      Http.fake({
        'auth/logout': Http.response({'message': 'Server Error'}, 500),
      });

      await MagicStarter.manager.runBeforeLogoutHooks();
      await Auth.logout();

      expect(Auth.check(), isFalse);
      expect(
        log.entries.where(
          (entry) => entry.level == 'warning' && entry.message.contains('500'),
        ),
        hasLength(1),
      );
    });

    test('a revoke that throws is logged, never rethrown', () async {
      await bootProvider();
      await signIn();
      Http.fake((MagicRequest request) => throw StateError('link down'));

      await expectLater(MagicStarter.manager.runBeforeLogoutHooks(), completes);
      expect(
        log.entries.where(
          (entry) =>
              entry.level == 'error' && entry.message.contains('link down'),
        ),
        hasLength(1),
      );
    });
  });
}
