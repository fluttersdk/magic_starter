import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(
      data: data ?? {},
      statusCode: statusCode,
    );
  }

  @override
  Future<MagicResponse> get(String url,
          {Map<String, dynamic>? query, Map<String, String>? headers}) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}
  @override
  Future<MagicResponse> post(String url,
          {dynamic data, Map<String, String>? headers}) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> put(String url,
          {dynamic data, Map<String, String>? headers}) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> delete(String url,
          {Map<String, String>? headers}) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> index(String resource,
          {Map<String, dynamic>? filters,
          Map<String, String>? headers}) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> show(String resource, String id,
          {Map<String, String>? headers}) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> store(String resource, Map<String, dynamic> data,
          {Map<String, String>? headers}) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> update(
          String resource, String id, Map<String, dynamic> data,
          {Map<String, String>? headers}) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> destroy(String resource, String id,
          {Map<String, String>? headers}) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> upload(String url,
          {required Map<String, dynamic> data,
          required Map<String, dynamic> files,
          Map<String, String>? headers}) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
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
            child: SizedBox(
              width: 1200,
              height: 2000,
              child: widget,
            ),
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
    });

    testWidgets(
        'tapping cancel invitation shows MagicStarterConfirmDialog with danger variant',
        (tester) async {
      controller.invitations.value = [
        {
          'id': 42,
          'email': 'invite@example.com',
          'role': 'member',
        },
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
    });

    testWidgets('no Material AlertDialog is used — uses ConfirmDialog instead',
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
    });
  });
}
