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
  }) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}
  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      nextResponse ?? MagicResponse(data: {}, statusCode: 200);
  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
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
            child: SizedBox(width: 1200, height: 2000, child: widget),
          ),
        ),
      ),
    );
  }

  group('MagicStarterTeamCreateView', () {
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

    // -----------------------------------------------------------------------
    // Rendering
    // -----------------------------------------------------------------------

    testWidgets('renders page header with correct title and subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterPageHeader), findsOneWidget);
      expect(find.text(trans('teams.create_team')), findsWidgets);
      expect(find.text(trans('teams.create_team_subtitle')), findsOneWidget);
    });

    testWidgets('renders team name form input with correct label', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      expect(find.byType(WFormInput), findsOneWidget);
      expect(
        find.widgetWithText(WFormInput, trans('teams.team_name')),
        findsOneWidget,
      );
    });

    testWidgets('renders submit button with create team text', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      expect(find.byType(WButton), findsOneWidget);
      expect(find.text(trans('teams.create_team')), findsWidgets);
    });

    // -----------------------------------------------------------------------
    // Widget structure
    // -----------------------------------------------------------------------

    testWidgets('uses MagicStarterCard as form container', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterCard), findsOneWidget);
    });

    testWidgets('uses MagicForm for form handling', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      expect(find.byType(MagicForm), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Wind UI compliance
    // -----------------------------------------------------------------------

    testWidgets('does not use Material AlertDialog', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('does not use Material ElevatedButton', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      expect(find.byType(ElevatedButton), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Layout structure
    // -----------------------------------------------------------------------

    testWidgets('wraps content in WDiv containers', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      // Outer container + form button container + card inner container
      expect(find.byType(WDiv), findsWidgets);
    });

    testWidgets('has exactly one form input and one button', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterTeamCreateView()));
      await tester.pumpAndSettle();

      expect(find.byType(WFormInput), findsOneWidget);
      expect(find.byType(WButton), findsOneWidget);
    });
  });
}
