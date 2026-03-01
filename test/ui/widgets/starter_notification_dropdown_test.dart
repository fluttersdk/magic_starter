import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  late StreamController<List<DatabaseNotification>> streamController;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    streamController = StreamController<List<DatabaseNotification>>.broadcast();

    // Mock LogManager
    Magic.singleton('log', () => LogManager());
    Config.set('logging', {
      'default': 'console',
      'channels': {
        'console': {'driver': 'console', 'level': 'debug'},
      },
    });
  });

  tearDown(() {
    streamController.close();
  });

  DatabaseNotification makeNotification({bool isRead = false}) {
    final now = DateTime.now();
    return DatabaseNotification.fromMap({
      'id': 'test-id-${now.millisecondsSinceEpoch}',
      'type': 'monitor_down',
      'data': {
        'title': 'Test Notification',
        'body': 'Test body',
        'action_url': null,
      },
      'read_at': isRead ? now.toIso8601String() : null,
      'created_at': now.toIso8601String(),
    });
  }

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: widget,
        ),
      ),
    );
  }

  testWidgets('renders bell icon', (tester) async {
    await tester.pumpWidget(wrap(StarterNotificationDropdown(
      notificationStream: streamController.stream,
    )));

    // Initially loading state
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

    // Provide empty data
    streamController.add([]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('shows unread badge when unread count > 0', (tester) async {
    await tester.pumpWidget(wrap(StarterNotificationDropdown(
      notificationStream: streamController.stream,
    )));

    streamController.add([
      makeNotification(isRead: false),
      makeNotification(isRead: false),
      makeNotification(isRead: true),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('hides badge when all notifications are read', (tester) async {
    await tester.pumpWidget(wrap(StarterNotificationDropdown(
      notificationStream: streamController.stream,
    )));

    streamController.add([
      makeNotification(isRead: true),
      makeNotification(isRead: true),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('renders empty state in popover content', (tester) async {
    await tester.pumpWidget(wrap(StarterNotificationDropdown(
      notificationStream: streamController.stream,
    )));

    streamController.add([]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap the bell to open popover
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('notifications.empty'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
  });
}
