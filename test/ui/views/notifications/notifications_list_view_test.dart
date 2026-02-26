import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/ui/views/notifications/notifications_list_view.dart';
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
      {Map<String, dynamic>? query, Map<String, String>? headers}) async {
    return nextResponse ?? MagicResponse(data: {}, statusCode: 500);
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}
  @override
  Future<MagicResponse> post(String url,
          {dynamic data, Map<String, String>? headers}) async =>
      nextResponse!;
  @override
  Future<MagicResponse> put(String url,
          {dynamic data, Map<String, String>? headers}) async =>
      nextResponse!;
  @override
  Future<MagicResponse> delete(String url,
          {Map<String, String>? headers}) async =>
      nextResponse!;
  @override
  Future<MagicResponse> index(String resource,
          {Map<String, dynamic>? filters,
          Map<String, String>? headers}) async =>
      nextResponse!;
  @override
  Future<MagicResponse> show(String resource, String id,
          {Map<String, String>? headers}) async =>
      nextResponse!;
  @override
  Future<MagicResponse> store(String resource, Map<String, dynamic> data,
          {Map<String, String>? headers}) async =>
      nextResponse!;
  @override
  Future<MagicResponse> update(
          String resource, String id, Map<String, dynamic> data,
          {Map<String, String>? headers}) async =>
      nextResponse!;
  @override
  Future<MagicResponse> destroy(String resource, String id,
          {Map<String, String>? headers}) async =>
      nextResponse!;
  @override
  Future<MagicResponse> upload(String url,
          {required Map<String, dynamic> data,
          required Map<String, dynamic> files,
          Map<String, String>? headers}) async =>
      nextResponse!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNetworkDriver mockDriver;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    mockDriver = MockNetworkDriver();
    Magic.singleton('network', () => mockDriver);
    Magic.singleton('log', () => LogManager());
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: SizedBox(
            width: 1024,
            height: 768,
            child: widget,
          ),
        ),
      ),
    );
  }

  group('MagicStarterNotificationsListView', () {
    testWidgets('renders loading state when data is loading', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterNotificationsListView()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state with icon and message', (tester) async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': [],
          'meta': {
            'current_page': 1,
            'last_page': 1,
            'per_page': 15,
            'total': 0,
          },
        },
      );

      await tester.pumpWidget(wrap(const MagicStarterNotificationsListView()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
      expect(find.text(trans('notifications.empty')), findsOneWidget);
    });

    testWidgets('renders notification items with title and body',
        (tester) async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': [
            {
              'id': '1',
              'type': 'monitor_down',
              'data': {
                'title': 'Monitor Down',
                'body': 'Your monitor is down',
                'action_url': '/monitors/1',
              },
              'read_at': null,
              'created_at': DateTime.now().toIso8601String(),
            }
          ],
          'meta': {
            'current_page': 1,
            'last_page': 1,
            'per_page': 15,
            'total': 1,
          },
        },
      );

      await tester.pumpWidget(wrap(const MagicStarterNotificationsListView()));
      await tester.pumpAndSettle();

      expect(find.text('Monitor Down'), findsOneWidget);
      expect(find.text('Your monitor is down'), findsOneWidget);
    });

    testWidgets('renders Mark all as read button when unread items exist',
        (tester) async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': [
            {
              'id': '1',
              'type': 'monitor_down',
              'data': {
                'title': 'Unread Notification',
                'body': 'Body',
              },
              'read_at': null,
              'created_at': DateTime.now().toIso8601String(),
            }
          ],
          'meta': {
            'current_page': 1,
            'last_page': 1,
            'per_page': 15,
            'total': 1,
          },
        },
      );

      await tester.pumpWidget(wrap(MagicStarterNotificationsListView(
        onMarkAllAsRead: () async {},
      )));
      await tester.pumpAndSettle();

      expect(find.text(trans('notifications.mark_all_read')), findsOneWidget);
    });
  });
}
