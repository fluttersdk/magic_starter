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
  List<String> get fillable => ['id', 'name', 'is_guest'];
}

_FakeUser _fakeUser({bool guest = false}) {
  final user = _FakeUser();
  user.fill({'id': 1, 'name': 'Alice', 'is_guest': guest});
  user.exists = true;
  return user;
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    Auth.unfake();
  });

  group('RedirectIfAuthenticated.redirectTarget', () {
    test('redirects an authenticated navigation to the home route', () {
      Auth.fake(user: _fakeUser());
      final middleware = RedirectIfAuthenticated();

      expect(
        middleware.redirectTarget('/auth/login'),
        MagicStarterConfig.homeRoute(),
      );
    });

    test('allows an authenticated user already resting on home (no loop)', () {
      Auth.fake(user: _fakeUser());
      final middleware = RedirectIfAuthenticated();

      expect(middleware.redirectTarget(MagicStarterConfig.homeRoute()), isNull);
    });

    test('lets a guest account through to sign in or register', () {
      // A guest session is authenticated, so `Auth.check()` alone sent it
      // home from the very pages that turn it into an account.
      Auth.fake(user: _fakeUser(guest: true));
      final middleware = RedirectIfAuthenticated();

      expect(middleware.redirectTarget('/auth/login'), isNull);
      expect(middleware.redirectTarget('/auth/register'), isNull);
    });

    test('allows an unauthenticated navigation to any guest route', () {
      Auth.fake();
      final middleware = RedirectIfAuthenticated();

      expect(middleware.redirectTarget('/auth/login'), isNull);
      expect(middleware.redirectTarget('/auth/register'), isNull);
    });
  });
}
