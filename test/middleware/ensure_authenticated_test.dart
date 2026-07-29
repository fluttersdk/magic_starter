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
  });

  tearDown(() {
    Auth.unfake();
  });

  group('EnsureAuthenticated.redirectTarget', () {
    test('redirects an unauthenticated navigation to the login route', () {
      Auth.fake();
      final middleware = EnsureAuthenticated();

      expect(
        middleware.redirectTarget('/'),
        MagicStarterConfig.loginRoute(),
      );
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
  });
}
