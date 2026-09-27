import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(data: data ?? {}, statusCode: statusCode);
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}
  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 200);
}

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

  group('MagicStarterTeamSettingsView — confirm dialogs', () {
    late MagicStarterTeamController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.singleton('network', () => MockNetworkDriver());
      Config.set('magic_starter.features.teams', true);
      Config.set('wind.colors.primary', 'indigo');
      controller = MagicStarterTeamController.instance;
    });

    tearDown(() {
      controller.members.dispose();
      controller.invitations.dispose();
      controller.currentTeamId.dispose();
    });

    testWidgets(
      'tapping remove member shows MagicStarterConfirmDialog with danger variant',
      (tester) async {
        controller.members.value = [
          {
            'id': 1,
            'name': 'Test User',
            'email': 'test@example.com',
            'role': 'member',
          },
        ];

        await tester.pumpWidget(wrap(const MagicStarterTeamSettingsView()));
        await tester.pumpAndSettle();

        // Find the close icon in the member row (remove action)
        final closeIcons = find.byIcon(Icons.close);
        expect(closeIcons, findsOneWidget);

        await tester.tap(closeIcons);
        await tester.pumpAndSettle();

        // Confirm dialog should appear with correct title and description
        expect(find.text(trans('teams.confirm_remove_member')), findsOneWidget);
        expect(find.text(trans('teams.remove')), findsOneWidget);
      },
    );

    testWidgets(
      'tapping cancel invitation shows MagicStarterConfirmDialog with danger variant',
      (tester) async {
        controller.invitations.value = [
          {'id': 42, 'email': 'invite@example.com', 'role': 'member'},
        ];

        await tester.pumpWidget(wrap(const MagicStarterTeamSettingsView()));
        await tester.pumpAndSettle();

        // Find the close icon in the invitation row (cancel action)
        final closeIcons = find.byIcon(Icons.close);
        expect(closeIcons, findsOneWidget);

        await tester.ensureVisible(closeIcons);
        await tester.pumpAndSettle();
        await tester.tap(closeIcons);
        await tester.pumpAndSettle();

        // Confirm dialog should appear
        expect(find.text(trans('teams.confirm_cancel_invite')), findsOneWidget);
      },
    );

    testWidgets(
      'no Material AlertDialog is used — uses ConfirmDialog instead',
      (tester) async {
        controller.members.value = [
          {
            'id': 1,
            'name': 'Test User',
            'email': 'test@example.com',
            'role': 'member',
          },
        ];

        await tester.pumpWidget(wrap(const MagicStarterTeamSettingsView()));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // Verify no Material AlertDialog in widget tree
        expect(find.byType(AlertDialog), findsNothing);
        // Verify MagicStarterConfirmDialog is used
        expect(find.byType(MagicStarterConfirmDialog), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Slot injection tests
  // -------------------------------------------------------------------------

  group('MagicStarterTeamSettingsView — slot injection', () {
    late MagicStarterTeamController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.singleton('network', () => MockNetworkDriver());
      Config.set('magic_starter.features.teams', true);
      Config.set('wind.colors.primary', 'indigo');
      controller = MagicStarterTeamController.instance;
    });

    tearDown(() {
      controller.members.dispose();
      controller.invitations.dispose();
      controller.currentTeamId.dispose();
    });

    testWidgets('header slot renders injected widget', (tester) async {
      MagicStarter.view.slot(
        'teams.settings',
        'header',
        (ctx) => const Text('Custom Header'),
      );

      await tester.pumpWidget(wrap(const MagicStarterTeamSettingsView()));
      await tester.pumpAndSettle();

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('footer slot renders injected widget', (tester) async {
      MagicStarter.view.slot(
        'teams.settings',
        'footer',
        (ctx) => const Text('Custom Footer'),
      );

      await tester.pumpWidget(wrap(const MagicStarterTeamSettingsView()));
      await tester.pumpAndSettle();

      expect(find.text('Custom Footer'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Theme consumption tests
  // -------------------------------------------------------------------------

  group('MagicStarterTeamSettingsView — theme consumption', () {
    late MagicStarterTeamController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.singleton('network', () => MockNetworkDriver());
      Config.set('magic_starter.features.teams', true);
      Config.set('wind.colors.primary', 'indigo');
      controller = MagicStarterTeamController.instance;
    });

    tearDown(() {
      controller.members.dispose();
      controller.invitations.dispose();
      controller.currentTeamId.dispose();
    });

    testWidgets('custom FormTheme renders without crash', (tester) async {
      MagicStarter.useFormTheme(
        const MagicStarterFormTheme(
          inputClassName: 'rounded-none border-2 border-blue-500',
          labelClassName: 'text-xs font-bold text-blue-700',
        ),
      );

      await tester.pumpWidget(wrap(const MagicStarterTeamSettingsView()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Session scope reset: a team switch must refresh THIS mounted screen
  // without a full app remount (see MagicStarterServiceProvider's
  // _ReloadOnAuthRestored and MagicStarterTeamController.resetForSession).
  // -------------------------------------------------------------------------

  group('MagicStarterTeamSettingsView, session scope reset', () {
    late MagicStarterTeamController controller;
    late FakeNetworkDriver network;
    dynamic activeTeamId;

    const teamX = MagicStarterTeam(id: 1, name: 'Team X');
    const teamY = MagicStarterTeam(id: 2, name: 'Team Y');

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      SessionScope.detach();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Config.set('magic_starter.features.teams', true);
      Config.set('wind.colors.primary', 'indigo');

      activeTeamId = 1;
      MagicStarter.useTeamResolver(
        currentTeam: () => activeTeamId == 1 ? teamX : teamY,
        allTeams: () => const [teamX, teamY],
        onSwitch: (dynamic id) => MagicStarter.switchTeam('$id'),
      );

      Auth.fake(
        user: MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Ada',
          'current_team_id': 1,
        }),
      );
      SessionScope.identity = () =>
          Auth.check() ? '${Auth.id()}:${MagicStarter.currentTeamId()}' : null;
      SessionScope.attach();

      // A callback stub, not a URL map: the members/invitations answer
      // depends on WHICH team the request names, and `activeTeamId` moves
      // once the PUT below lands, exactly the way a real backend would move
      // its own current-team pointer.
      network = Http.fake((MagicRequest request) {
        if (request.method == 'PUT' && request.url == '/user/current-team') {
          activeTeamId = (request.data as Map<String, dynamic>)['team_id'];
          return Http.response({
            'data': {'id': 1, 'name': 'Ada', 'current_team_id': activeTeamId},
          });
        }
        if (request.method == 'GET' && request.url == '/teams/1/members') {
          return Http.response({
            'data': [
              {
                'id': 10,
                'name': 'Alice X',
                'email': 'alice@x.example',
                'role': 'owner',
              },
            ],
          });
        }
        if (request.method == 'GET' && request.url == '/teams/2/members') {
          return Http.response({
            'data': [
              {
                'id': 20,
                'name': 'Bob Y',
                'email': 'bob@y.example',
                'role': 'owner',
              },
            ],
          });
        }
        // Invitations: empty for both teams, and the catch-all for anything
        // else this test does not care about.
        return Http.response({'data': []});
      });

      controller = MagicStarterTeamController.instance;
    });

    tearDown(() {
      SessionScope.detach();
      Auth.unfake();
      Http.unfake();
      controller.members.dispose();
      controller.invitations.dispose();
      controller.currentTeamId.dispose();
    });

    testWidgets(
      'reseeds the name field and reloads members for the team a switch '
      'landed on, while this view stays mounted',
      (tester) async {
        await tester.pumpWidget(wrap(const MagicStarterTeamSettingsView()));
        await tester.pumpAndSettle();

        expect(find.text('Team X'), findsOneWidget);
        expect(find.text('Alice X'), findsOneWidget);

        final switched = await controller.switchTeam(2);
        expect(switched, isTrue);

        // The fake guard's `setUser` does not bump `Auth.stateNotifier` on
        // its own (only a real `login`/`logout` does), so this drives the
        // sync a real guard would have triggered from inside `setUser`.
        SessionScope.sync();
        await tester.pumpAndSettle();

        expect(find.text('Team Y'), findsOneWidget);
        expect(find.text('Bob Y'), findsOneWidget);
        expect(find.text('Team X'), findsNothing);
        expect(find.text('Alice X'), findsNothing);
        network.assertSent(
          (r) => r.method == 'GET' && r.url == '/teams/2/members',
        );
      },
    );
  });
}
