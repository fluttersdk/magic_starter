import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The first four bytes of every PNG file.
const List<int> _pngSignature = <int>[0x89, 0x50, 0x4E, 0x47];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    MagicStarterScreenCapture.resetForTesting();

    Magic.singleton('log', () => LogManager());
    Config.set('logging', <String, dynamic>{
      'default': 'console',
      'channels': <String, dynamic>{
        'console': <String, dynamic>{'driver': 'console', 'level': 'debug'},
      },
    });
    Config.set('magic_starter.features.support', true);
    Config.set('magic_starter.features.support_diagnostics', true);
    Config.set('magic_starter.diagnostics.deny_capture_routes', <String>[
      '/reports',
    ]);
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Auth.fake(
      user: MagicStarterAuthUser.fromMap(<String, dynamic>{
        'id': 5,
        'name': 'Ada Lovelace',
      }),
    );
  });

  tearDown(() {
    MagicStarterScreenCapture.resetForTesting();
    Kernel.flush();
    Auth.unfake();
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  /// Mounts a router with a plain page at each of [pages] plus the starter's
  /// own support routes, every screen a solid block so there is something to
  /// paint.
  Future<void> mount(
    WidgetTester tester, {
    required String at,
    List<String> pages = const <String>['/dashboard'],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 600);
    addTearDown(tester.view.reset);

    Kernel.register('auth', AllowAllMiddleware.new);
    MagicStarter.view.registerLayout('layout.app', (child) => child);
    MagicStarter.view.register(
      'support.index',
      () => const ColoredBox(color: Color(0xFF00FF00), child: Text('support')),
    );

    for (final String path in pages) {
      MagicRoute.page(
        path,
        () => ColoredBox(color: const Color(0xFF0000FF), child: Text(path)),
      );
    }
    registerMagicStarterSupportRoutes();
    MagicRouter.instance.setInitialLocation(at);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: MagicRouter.instance.routerConfig,
        builder: (context, child) => MagicStarterScreenCapture.wrap(child!),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Navigates to [path] and waits for the capture it started, in real time:
  /// rasterising a layer is not driven by the fake clock.
  Future<void> navigate(WidgetTester tester, String path) async {
    await tester.runAsync(() async {
      MagicRoute.to(path);
      await MagicStarterScreenCapture.debugCaptureSettled;
    });
    await tester.pumpAndSettle();
  }

  testWidgets('entering support holds a PNG of the screen that was left', (
    tester,
  ) async {
    await mount(tester, at: '/dashboard');

    await navigate(tester, '/support');

    final bytes = MagicStarterScreenCapture.holder.bytes;
    expect(bytes, isNotNull);
    expect(bytes!.sublist(0, 4), _pngSignature);
    expect(MagicStarterScreenCapture.holder.route, '/dashboard');
  });

  testWidgets('the route it records carries no query', (tester) async {
    await mount(tester, at: '/dashboard?tab=all');

    await navigate(tester, '/support');

    expect(MagicStarterScreenCapture.holder.route, '/dashboard');
  });

  testWidgets('a starter deny-listed screen is never captured', (tester) async {
    await mount(
      tester,
      at: MagicStarterConfig.settingsPasswordRoute(),
      pages: <String>[MagicStarterConfig.settingsPasswordRoute()],
    );

    await navigate(tester, '/support');

    expect(MagicStarterScreenCapture.holder.bytes, isNull);
  });

  testWidgets('a team screen is never captured', (tester) async {
    await mount(
      tester,
      at: MagicStarterConfig.teamSettingsRoute(),
      pages: <String>[MagicStarterConfig.teamSettingsRoute()],
    );

    await navigate(tester, '/support');

    expect(MagicStarterScreenCapture.holder.bytes, isNull);
  });

  testWidgets('a screen the app deny-lists is never captured', (tester) async {
    await mount(tester, at: '/reports/7', pages: <String>['/reports/7']);

    await navigate(tester, '/support');

    expect(MagicStarterScreenCapture.holder.bytes, isNull);
  });

  testWidgets('nothing is captured while a dialog is open', (tester) async {
    await mount(tester, at: '/dashboard');

    showDialog<void>(
      context: MagicRouter.instance.navigatorKey.currentContext!,
      builder: (_) => const Center(child: Text('secret dialog')),
    );
    await tester.pumpAndSettle();

    await navigate(tester, '/support');

    expect(MagicStarterScreenCapture.holder.bytes, isNull);
  });

  testWidgets('a deny-listed visit drops the screenshot an earlier one held', (
    tester,
  ) async {
    await mount(
      tester,
      at: '/dashboard',
      pages: <String>['/dashboard', '/reports'],
    );
    await navigate(tester, '/support');
    expect(MagicStarterScreenCapture.holder.bytes, isNotNull);

    await navigate(tester, '/reports');
    await navigate(tester, '/support');

    expect(MagicStarterScreenCapture.holder.bytes, isNull);
  });

  testWidgets('nothing is captured while the diagnostics feature is off', (
    tester,
  ) async {
    Config.set('magic_starter.features.support_diagnostics', false);
    await mount(tester, at: '/dashboard');

    await navigate(tester, '/support');

    expect(MagicStarterScreenCapture.holder.bytes, isNull);
  });

  testWidgets('a sign-in drops the previous account screenshot', (
    tester,
  ) async {
    await mount(tester, at: '/dashboard');
    await navigate(tester, '/support');
    expect(MagicStarterScreenCapture.holder.bytes, isNotNull);

    await MagicStarterScreenCapture.holder.resetForSession();

    expect(MagicStarterScreenCapture.holder.bytes, isNull);
    expect(MagicStarterScreenCapture.holder.route, isNull);
  });
}
