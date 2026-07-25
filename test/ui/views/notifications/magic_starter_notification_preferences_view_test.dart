import 'package:flutter/material.dart' hide Switch;
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

      // Check for design-system Switch toggles
      expect(find.byType(MSSwitch), findsNWidgets(2));
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

      // The design-system Switch uses disabled:true for locked channels
      // rather than setting onChanged to null.
      final switchWidget = tester.widget<MSSwitch>(find.byType(MSSwitch));
      expect(switchWidget.disabled, isTrue);
    });
  });

  group('MagicStarterNotificationPreferencesView — push hint', () {
    /// Mock a matrix carrying a push channel plus one non-push sibling, with
    /// the backend's `meta.push_provisioned` flag when [pushProvisioned] is set.
    void mockPushMatrix({bool? pushProvisioned}) {
      mockDriver.mockResponse(statusCode: 200, data: {
        'data': {
          'monitor_down': {
            'label': 'Monitor Down Alert',
            'channels': {
              'push': {'enabled': true, 'locked': false},
              'mail': {'enabled': true, 'locked': false},
            }
          }
        },
        if (pushProvisioned != null)
          'meta': {'push_provisioned': pushProvisioned},
      });
    }

    /// Widen the surface: no lang loader runs here, so trans() yields the raw
    /// key and the hint is far wider than its translated copy.
    void widen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets(
        'renders the hint when the backend reports push as unprovisioned',
        (tester) async {
      widen(tester);
      mockPushMatrix(pushProvisioned: false);

      await tester
          .pumpWidget(wrap(const MagicStarterNotificationPreferencesView()));
      await tester.pumpAndSettle();

      expect(
        find.text(trans('notifications.channel_push_unconfigured')),
        findsOneWidget,
      );
      expect(
        MagicStarterNotificationController
            .instance.pushProvisionedNotifier.value,
        isFalse,
      );
    });

    testWidgets('renders no hint when the backend reports push as provisioned',
        (tester) async {
      widen(tester);
      mockPushMatrix(pushProvisioned: true);

      await tester
          .pumpWidget(wrap(const MagicStarterNotificationPreferencesView()));
      await tester.pumpAndSettle();

      expect(
        find.text(trans('notifications.channel_push_unconfigured')),
        findsNothing,
      );
    });

    testWidgets('renders no hint when the payload carries no provisioning flag',
        (tester) async {
      widen(tester);
      mockPushMatrix();

      await tester
          .pumpWidget(wrap(const MagicStarterNotificationPreferencesView()));
      await tester.pumpAndSettle();

      // A backend that predates the flag (or a degraded payload) must not read
      // as "push not configured": the optimistic default stands.
      expect(
        find.text(trans('notifications.channel_push_unconfigured')),
        findsNothing,
      );
    });

    testWidgets('a host override wins over the backend flag', (tester) async {
      widen(tester);
      mockPushMatrix(pushProvisioned: false);

      await tester.pumpWidget(wrap(
        const MagicStarterNotificationPreferencesView(pushProvisioned: true),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text(trans('notifications.channel_push_unconfigured')),
        findsNothing,
      );
    });

    testWidgets('keeps the hint out of the label semantics exclusion',
        (tester) async {
      widen(tester);
      mockPushMatrix();

      await tester.pumpWidget(wrap(
        const MagicStarterNotificationPreferencesView(
          pushProvisioned: false,
        ),
      ));
      await tester.pumpAndSettle();

      // The channel label is excluded (the switch carries it as its
      // semanticLabel), but the hint must stay announceable: it says something
      // the switch label does not.
      expect(
        find.descendant(
          of: find.byType(ExcludeSemantics),
          matching: find.text(trans('notifications.channel_push')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ExcludeSemantics),
          matching: find.text(trans('notifications.channel_push_unconfigured')),
        ),
        findsNothing,
      );
    });
  });

  group('MagicStarterNotificationPreferencesView — slot injection', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      mockDriver = MockNetworkDriver();
      Magic.singleton('network', () => mockDriver);
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Config.set('magic_starter.features.notifications', true);

      mockDriver.mockResponse(statusCode: 200, data: {'data': {}});

      // Pre-instantiate the controller so onInit fires.
      MagicStarterNotificationController.instance;
    });

    testWidgets('renders header slot when registered', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      MagicStarter.view.slot(
        'notifications.preferences',
        'header',
        (ctx) => const Text('Custom Header'),
      );

      await tester.pumpWidget(
        wrap(const MagicStarterNotificationPreferencesView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('renders footer slot when registered', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      MagicStarter.view.slot(
        'notifications.preferences',
        'footer',
        (ctx) => const Text('Custom Footer'),
      );

      await tester.pumpWidget(
        wrap(const MagicStarterNotificationPreferencesView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Footer'), findsOneWidget);
    });
  });
}
