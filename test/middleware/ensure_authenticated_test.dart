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
}
