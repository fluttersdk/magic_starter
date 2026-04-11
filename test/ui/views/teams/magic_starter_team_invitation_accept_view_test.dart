import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;
  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(data: data ?? {}, statusCode: statusCode);
  }

  MagicResponse _respond(String method, String url, {dynamic data}) {
    lastMethod = method;
    lastUrl = url;
    lastData = data;
    return nextResponse ?? MagicResponse(data: {}, statusCode: 200);
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

// ---------------------------------------------------------------------------
// Mock Guard
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool restoreCalled = false;

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
  Future<void> restore() async => restoreCalled = true;
  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  Widget wrap(Widget widget) {
    final themeData = WindThemeData(
      colors: {
        'primary': Colors.indigo,
        'danger': Colors.red,
        'warning': Colors.amber,
      },
    );
    return WindTheme(
      data: themeData,
      child: MaterialApp(
        theme: themeData.toThemeData(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 1200, height: 2000, child: widget),
          ),
        ),
      ),
    );
  }

  group('MagicStarterTeamInvitationAcceptView', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late MagicStarterTeamController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      // Bind LogManager.
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      // Bind mock network driver.
      Magic.singleton('network', () => MockNetworkDriver());

      // Bind mock guard.
      mockGuard = MockGuard();
      Magic.singleton('auth', () => AuthManager());
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {'driver': 'mock'}
      });

      // Bind MagicStarterManager.
      Magic.singleton('magic_starter', () => MagicStarterManager());

      // Enable team features and set home route.
      Config.set('magic_starter.features.teams', true);
      Config.set('magic_starter.routes.home', '/dashboard');
      Config.set('wind.colors.primary', 'indigo');

      // Resolve mock driver.
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;

      // Create controller.
      controller = MagicStarterTeamController.instance;
    });

    tearDown(() {
      controller.currentTeamId.dispose();
      controller.members.dispose();
      controller.invitations.dispose();
      Auth.manager.forgetGuards();
    });

    // -----------------------------------------------------------------------
    // Default (empty) state
    // -----------------------------------------------------------------------

    testWidgets('default state renders accept button with group_add icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.group_add_outlined), findsOneWidget);
      expect(find.text(trans('teams.accept_invitation')), findsWidgets);
    });

    testWidgets('default state renders card title and subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(trans('teams.accept_invitation_subtitle')),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // Accept button interaction
    // -----------------------------------------------------------------------

    testWidgets(
        'tapping accept button sends POST to invitation accept endpoint',
        (tester) async {
      // Use failure response so MagicRoute.to() is NOT called after.
      mockDriver.mockResponse(
        statusCode: 422,
        data: {'message': 'Invitation expired'},
      );

      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      final button = find.byWidgetPredicate(
        (w) => w is WButton && w.isLoading == false,
      );
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(mockDriver.lastMethod, 'POST');
      expect(mockDriver.lastUrl, contains('/invitations/'));
      expect(mockDriver.lastUrl, contains('/accept'));
    });

    // -----------------------------------------------------------------------
    // Success state
    // -----------------------------------------------------------------------

    testWidgets('success state renders check icon and accepted text', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      // Set success state after onInit has cleared — avoids MagicRoute.to().
      controller.setSuccess(true);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text(trans('teams.invite_accepted')), findsOneWidget);
    });

    testWidgets('success state renders dashboard link', (tester) async {
      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      controller.setSuccess(true);
      await tester.pumpAndSettle();

      expect(find.text(trans('common.go_to_dashboard')), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Error state
    // -----------------------------------------------------------------------

    testWidgets('error state renders error icon and error banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      // Set error state after onInit has cleared.
      controller.setError('Invitation expired');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Invitation expired'), findsOneWidget);
    });

    testWidgets('error state renders dashboard link', (tester) async {
      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      controller.setError('Something went wrong');
      await tester.pumpAndSettle();

      expect(find.text(trans('common.go_to_dashboard')), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    testWidgets('empty token does not crash the view', (tester) async {
      // Token defaults to empty string when MagicRouter has no path parameters.
      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      // View renders without crashing.
      expect(find.byIcon(Icons.group_add_outlined), findsOneWidget);
    });

    testWidgets('onInit clears errors and sets empty state', (tester) async {
      // Pre-set an error on the controller.
      controller.setError('Previous error');

      await tester.pumpWidget(
        wrap(const MagicStarterTeamInvitationAcceptView()),
      );
      await tester.pumpAndSettle();

      // onInit should clear the error and set empty — showing default state.
      expect(find.byIcon(Icons.group_add_outlined), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });
}
