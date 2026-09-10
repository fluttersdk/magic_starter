import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Minimal authenticated user for the fake auth manager, mirroring the
/// `_FakeUser` helper in `magic/test/routing/router_auth_refresh_test.dart`.
class _FakeUser extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['id', 'name'];
}

_FakeUser _fakeUser() {
  final user = _FakeUser();
  user.fill({'id': 1, 'name': 'Alice'});
  user.exists = true;
  return user;
}

void main() {
  // The starter provider's boot reads `WidgetsBinding.instance` for its primary
  // colour fallback, and one group below boots it for real.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
  });

  tearDown(() {
    Auth.unfake();
  });

  group('EnsureAuthenticated.redirectTarget', () {
    test('redirects an unauthenticated navigation to the login route', () {
      Auth.fake();
      final middleware = EnsureAuthenticated();

      expect(middleware.redirectTarget('/'), MagicStarterConfig.loginRoute());
    });

    test('allows a guest already resting on the login route (no loop)', () {
      Auth.fake();
      final middleware = EnsureAuthenticated();

      expect(
        middleware.redirectTarget(MagicStarterConfig.loginRoute()),
        isNull,
      );
    });

    test('allows an authenticated navigation to any route', () {
      Auth.fake(user: _fakeUser());
      final middleware = EnsureAuthenticated();

      expect(middleware.redirectTarget('/'), isNull);
      expect(middleware.redirectTarget('/monitors'), isNull);
    });

    test('records the requested location as the intended URL before bouncing '
        'to login', () {
      Auth.fake();
      final middleware = EnsureAuthenticated();

      middleware.redirectTarget('/incidents/123');

      expect(MagicRouter.instance.hasIntendedUrl, isTrue);
      expect(MagicRouter.instance.pullIntendedUrl(), '/incidents/123');
    });

    test(
      'records nothing when the bounce target is itself a guest-only auth '
      'route, so a bounced visitor is never sent back to one they cannot use',
      () {
        Auth.fake();
        final middleware = EnsureAuthenticated();

        middleware.redirectTarget('/auth/register');
        expect(MagicRouter.instance.hasIntendedUrl, isFalse);

        middleware.redirectTarget('/auth/forgot-password');
        expect(MagicRouter.instance.hasIntendedUrl, isFalse);
      },
    );

    test('records nothing for an authenticated navigation', () {
      Auth.fake(user: _fakeUser());
      final middleware = EnsureAuthenticated();

      middleware.redirectTarget('/monitors');

      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
    });
  });

  group('the intended url a sign-out recorded', () {
    /// Boots the starter provider, which is what registers the clear.
    ///
    /// Through the provider rather than a helper, because the finding this
    /// covers was that the clear used to hang off `SessionScopeSync.attach()`,
    /// which is OPT-IN and which nothing in this package calls: an app that
    /// never adopted session scoping had no clear at all. Booting the provider
    /// is what every starter app does, so that is what the test does.
    Future<void> bootProvider() async {
      final provider = MagicStarterServiceProvider(MagicApp.instance);
      provider.register();
      await provider.boot();
    }

    test('is discarded when the session ends', () async {
      Auth.fake(user: _fakeUser());
      await bootProvider();

      // What EnsureAuthenticated writes down when the auth flip re-runs
      // go_router's redirects while the app is still on a protected route.
      MagicRouter.instance.setIntendedUrl('/teams/settings');

      await Auth.logout();
      await pumpEventQueue();

      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
    });

    test('survives the login it was recorded for', () async {
      Auth.fake();
      await bootProvider();

      // The whole point of the intent: a deep link lands on a signed-out
      // device, the middleware records it, and the login that follows consumes
      // it. Signing in bumps the same notifier a sign-out does, so a clear hung
      // off the bump itself would eat the feature it protects.
      MagicRouter.instance.setIntendedUrl('/incidents/1');

      await Auth.login({'token': 't'}, _fakeUser());
      await pumpEventQueue();

      expect(MagicRouter.instance.pullIntendedUrl(), '/incidents/1');
    });
  });
}
