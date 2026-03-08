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
  late MagicStarterNotificationController controller;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    mockDriver = MockNetworkDriver();
    Magic.singleton('network', () => mockDriver);
    Magic.singleton('log', () => LogManager());
    Magic.singleton('magic_starter', () => MagicStarterManager());

    controller = MagicStarterNotificationController.instance;
  });

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 800,
              child: widget,
            ),
          ),
        ),
      ),
    );
  }

  group('MagicStarterNotificationPreferencesView', () {
    testWidgets('renders loading state when preferences are loading',
        (tester) async {
      // Set loading state before pumping to avoid race condition with onInit
      controller.setLoading();

      await tester
          .pumpWidget(wrap(const MagicStarterNotificationPreferencesView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty matrix state when matrix is empty',
        (tester) async {
      mockDriver.mockResponse(statusCode: 200, data: {'data': {}});

      await tester
          .pumpWidget(wrap(const MagicStarterNotificationPreferencesView()));
      await tester.pumpAndSettle();

      expect(find.text(trans('notifications.no_preferences')), findsOneWidget);
    });

    testWidgets('renders matrix with checkboxes for each type and channel',
        (tester) async {
      // Widen the test surface so untranslated trans() keys fit without overflow.
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final matrix = {
        'monitor_down': {
          'label': 'Monitor Down Alert',
          'channels': {
            'mail': {'enabled': true, 'locked': false},
            'slack': {'enabled': false, 'locked': false},
          }
        }
      };

      mockDriver.mockResponse(statusCode: 200, data: {'data': matrix});

      await tester
          .pumpWidget(wrap(const MagicStarterNotificationPreferencesView()));
      await tester.pumpAndSettle();

      expect(find.text('Monitor Down Alert'), findsOneWidget);
      expect(find.text(trans('notifications.channel_email')), findsOneWidget);
      expect(find.text('Slack'), findsOneWidget);

      // Check for WCheckbox toggles
      expect(find.byType(Switch), findsNWidgets(2));
    });

    testWidgets('locked channel checkbox is disabled', (tester) async {
      // Widen the test surface so untranslated trans() keys fit without overflow.
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final matrix = {
        'monitor_down': {
          'label': 'Monitor Down Alert',
          'channels': {
            'mail': {'enabled': true, 'locked': true},
          }
        }
      };

      mockDriver.mockResponse(statusCode: 200, data: {'data': matrix});

      await tester
          .pumpWidget(wrap(const MagicStarterNotificationPreferencesView()));
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);
    });
  });
}
