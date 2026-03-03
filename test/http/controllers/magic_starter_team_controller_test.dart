import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver — intercepts all Http facade calls
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  final List<RecordedCall> calls = [];
  final Map<String, MagicResponse> _stubbedResponses = {};
  MagicResponse? _defaultResponse;

  /// Stub a response for a specific URL pattern.
  void stubResponse(
    String urlPattern, {
    required int statusCode,
    dynamic data,
  }) {
    _stubbedResponses[urlPattern] = MagicResponse(
      data: data ?? {},
      statusCode: statusCode,
    );
  }

  /// Set a default response for any un-stubbed URL.
  void setDefaultResponse({
    required int statusCode,
    dynamic data,
  }) {
    _defaultResponse = MagicResponse(
      data: data ?? {},
      statusCode: statusCode,
    );
  }

  MagicResponse _respond(String method, String url, {dynamic data}) {
    calls.add(RecordedCall(method: method, url: url, data: data));

    // 1. Try exact match.
    if (_stubbedResponses.containsKey(url)) {
      return _stubbedResponses[url]!;
    }

    // 2. Try prefix match (for dynamic URLs like /teams/5/members).
    for (final entry in _stubbedResponses.entries) {
      if (url.startsWith(entry.key) || url.contains(entry.key)) {
        return entry.value;
      }
    }

    // 3. Fall back to default.
    return _defaultResponse ?? MagicResponse(data: {}, statusCode: 500);
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async =>
      _respond('GET', url);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _respond('INDEX', resource);

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
      _respond('UPLOAD', url, data: data);
}

class RecordedCall {
  final String method;
  final String url;
  final dynamic data;

  const RecordedCall({
    required this.method,
    required this.url,
    this.data,
  });
}

// ---------------------------------------------------------------------------
// Mock Guard — tracks Auth calls
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool restoreCalled = false;
  bool logoutCalled = false;

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    _user = user;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    _user = null;
  }

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
  Future<void> restore() async {
    restoreCalled = true;
  }

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MagicStarterTeamController', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late MagicStarterTeamController controller;

    setUp(() {
      // 1. Reset IoC container.
      MagicApp.reset();
      Magic.flush();

      // 2. Bind mock network driver for Http facade.
      Magic.singleton('network', () => MockNetworkDriver());

      // 3. Bind LogManager so Log.error() works in catch blocks.
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      // 4. Bind mock guard for Auth facade.
      mockGuard = MockGuard();
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {
          'driver': 'mock',
        },
      });

      // 5. Bind MagicStarterManager for MagicStarter facade.
      Magic.singleton('magic_starter', () => MagicStarterManager());

      // 6. Resolve mock driver.
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;

      // 7. Create a fresh controller instance.
      controller = MagicStarterTeamController();
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
    });

    // ---------------------------------------------------------------------
    // doCreate
    // ---------------------------------------------------------------------

    group('doCreate', () {
      test('success — returns true, sets success, calls Auth.restore()',
          () async {
        mockDriver.stubResponse(
          '/teams',
          statusCode: 200,
          data: {
            'data': {
              'id': 10,
              'name': 'New Team',
            },
          },
        );

        final result = await controller.doCreate(name: 'New Team');

        expect(result, isTrue);
        expect(controller.isSuccess, isTrue);
        expect(controller.currentTeamId.value, equals(10));
        expect(mockGuard.restoreCalled, isTrue);

        // Verify POST was made to /teams.
        final postCalls = mockDriver.calls.where(
          (c) => c.method == 'POST' && c.url == '/teams',
        );
        expect(postCalls, hasLength(1));
      });

      test('failure (422) — returns false, sets error', () async {
        mockDriver.stubResponse(
          '/teams',
          statusCode: 422,
          data: {
            'message': 'Validation failed',
            'errors': {
              'name': ['Team name is required.'],
            },
          },
        );

        final result = await controller.doCreate(name: '');

        expect(result, isFalse);
        expect(controller.isSuccess, isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // doUpdate
    // ---------------------------------------------------------------------

    group('doUpdate', () {
      test('returns false when no active team', () async {
        // No team ID set.
        final result = await controller.doUpdate(name: 'Updated');

        expect(result, isFalse);
        expect(controller.isError, isTrue);
      });

      test('success — returns true, calls Auth.restore()', () async {
        controller.currentTeamId.value = 5;

        mockDriver.stubResponse(
          '/teams/5',
          statusCode: 200,
          data: {
            'data': {
              'id': 5,
              'name': 'Updated Team',
            },
          },
        );

        final result = await controller.doUpdate(name: 'Updated Team');

        expect(result, isTrue);
        expect(controller.isSuccess, isTrue);
        expect(mockGuard.restoreCalled, isTrue);
      });

      test('failure — returns false, sets error', () async {
        controller.currentTeamId.value = 5;

        mockDriver.stubResponse(
          '/teams/5',
          statusCode: 422,
          data: {
            'message': 'Validation failed',
            'errors': {
              'name': ['Too short.'],
            },
          },
        );

        final result = await controller.doUpdate(name: 'A');

        expect(result, isFalse);
        expect(controller.isSuccess, isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // doInvite
    // ---------------------------------------------------------------------

    group('doInvite', () {
      test('returns false when no active team', () async {
        final result = await controller.doInvite(
          email: 'user@example.com',
          role: 'member',
        );

        expect(result, isFalse);
        expect(controller.isError, isTrue);
      });

      test('success — returns true', () async {
        controller.currentTeamId.value = 5;

        // Stub both invitations POST and the subsequent
        // loadMembersAndInvitations GET calls.
        mockDriver.setDefaultResponse(
          statusCode: 200,
          data: {'data': []},
        );

        final result = await controller.doInvite(
          email: 'new@example.com',
          role: 'editor',
        );

        expect(result, isTrue);

        // Verify POST was made to /teams/5/invitations.
        final postCalls = mockDriver.calls.where(
          (c) => c.method == 'POST' && c.url == '/teams/5/invitations',
        );
        expect(postCalls, hasLength(1));
      });

      test('failure — returns false', () async {
        controller.currentTeamId.value = 5;

        mockDriver.stubResponse(
          '/teams/5/invitations',
          statusCode: 422,
          data: {
            'message': 'Already invited',
            'errors': {
              'email': ['User already invited.'],
            },
          },
        );

        final result = await controller.doInvite(
          email: 'existing@example.com',
          role: 'member',
        );

        expect(result, isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // removeMember
    // ---------------------------------------------------------------------

    group('removeMember', () {
      test('returns false when no active team', () async {
        final result = await controller.removeMember(42);

        expect(result, isFalse);
      });

      test('success — removes member from list, returns true', () async {
        controller.currentTeamId.value = 5;
        controller.members.value = [
          {'id': 1, 'name': 'Alice'},
          {'id': 2, 'name': 'Bob'},
        ];

        mockDriver.setDefaultResponse(statusCode: 200, data: {});

        final result = await controller.removeMember(1);

        expect(result, isTrue);
        expect(controller.members.value, hasLength(1));
        expect(controller.members.value.first['name'], equals('Bob'));
      });
    });

    // ---------------------------------------------------------------------
    // switchTeam
    // ---------------------------------------------------------------------

    group('switchTeam', () {
      test('success — sets currentTeamId and calls Auth.restore()', () async {
        mockDriver.stubResponse(
          '/user/current-team',
          statusCode: 200,
          data: {},
        );

        final result = await controller.switchTeam(7);

        expect(result, isTrue);
        expect(controller.currentTeamId.value, equals(7));
        expect(mockGuard.restoreCalled, isTrue);
        expect(controller.isSuccess, isTrue);
      });

      test('failure — returns false, does not change currentTeamId', () async {
        mockDriver.stubResponse(
          '/user/current-team',
          statusCode: 422,
          data: {'message': 'Invalid team'},
        );

        final result = await controller.switchTeam(999);

        expect(result, isFalse);
        expect(controller.currentTeamId.value, isNot(equals(999)));
      });
    });

    // ---------------------------------------------------------------------
    // doAcceptInvitation
    // ---------------------------------------------------------------------

    group('doAcceptInvitation', () {
      test('success — returns true, calls Auth.restore()', () async {
        mockDriver.stubResponse(
          '/invitations/abc123/accept',
          statusCode: 200,
          data: {},
        );

        final result = await controller.doAcceptInvitation(token: 'abc123');

        expect(result, isTrue);
        expect(controller.isSuccess, isTrue);
        expect(mockGuard.restoreCalled, isTrue);
      });

      test('failure — returns false', () async {
        mockDriver.stubResponse(
          '/invitations/expired/accept',
          statusCode: 422,
          data: {'message': 'Invitation expired'},
        );

        final result = await controller.doAcceptInvitation(token: 'expired');

        expect(result, isFalse);
        expect(controller.isSuccess, isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // cancelInvitation
    // ---------------------------------------------------------------------

    group('cancelInvitation', () {
      test('returns false when no active team', () async {
        final result = await controller.cancelInvitation(10);

        expect(result, isFalse);
      });

      test('success — removes invitation from list, returns true', () async {
        controller.currentTeamId.value = 5;
        controller.invitations.value = [
          {'id': 10, 'email': 'a@b.com'},
          {'id': 20, 'email': 'c@d.com'},
        ];

        mockDriver.setDefaultResponse(statusCode: 200, data: {});

        final result = await controller.cancelInvitation(10);

        expect(result, isTrue);
        expect(controller.invitations.value, hasLength(1));
        expect(
          controller.invitations.value.first['email'],
          equals('c@d.com'),
        );
      });
    });

    // ---------------------------------------------------------------------
    // loadMembersAndInvitations
    // ---------------------------------------------------------------------

    group('loadMembersAndInvitations', () {
      test('populates members and invitations on success', () async {
        controller.currentTeamId.value = 5;

        mockDriver.stubResponse(
          '/teams/5/members',
          statusCode: 200,
          data: {
            'data': [
              {'id': 1, 'name': 'Alice'},
              {'id': 2, 'name': 'Bob'},
            ],
          },
        );
        mockDriver.stubResponse(
          '/teams/5/invitations',
          statusCode: 200,
          data: {
            'data': [
              {'id': 10, 'email': 'pending@example.com'},
            ],
          },
        );

        await controller.loadMembersAndInvitations();

        expect(controller.members.value, hasLength(2));
        expect(controller.invitations.value, hasLength(1));
        expect(controller.isSuccess, isTrue);
      });

      test('does nothing when no active team', () async {
        await controller.loadMembersAndInvitations();

        expect(controller.members.value, isEmpty);
        expect(controller.invitations.value, isEmpty);
      });
    });

    // ---------------------------------------------------------------------
    // Concurrent submission guard
    // ---------------------------------------------------------------------

    group('submission guard', () {
      test('prevents double submission on doCreate', () async {
        controller.currentTeamId.value = 5;
        mockDriver.setDefaultResponse(
          statusCode: 200,
          data: {
            'data': {'id': 10}
          },
        );

        final future1 = controller.doCreate(name: 'Team A');
        final future2 = controller.doCreate(name: 'Team B');

        await Future.wait([future1, future2]);

        // Only one POST should have been made.
        final postCalls = mockDriver.calls.where(
          (c) => c.method == 'POST',
        );
        expect(postCalls, hasLength(1));
      });
    });
  });
}
