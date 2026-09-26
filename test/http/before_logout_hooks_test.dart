import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  // The provider's boot reads `WidgetsBinding.instance` for its primary colour
  // fallback, and the default-hook tests boot it for real.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> order;
  late FakeLogManager log;

  /// Records the sign-out itself, the moment the guard drops the session.
  void recordSignOut() {
    if (!Auth.check()) order.add('Auth.logout');
  }

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    log = Log.fake();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Config.set('magic_starter.features.notifications', false);
    Config.set('notifications.push_state.report_path', null);
    Config.set('notifications.push_state.release_path', null);

    Auth.fake(user: MagicStarterAuthUser.fromMap({'id': 42, 'name': 'Alice'}));
    Auth.stateNotifier.addListener(recordSignOut);

    order = <String>[];
  });

  tearDown(() {
    Auth.stateNotifier.removeListener(recordSignOut);
    Auth.unfake();
    Log.unfake();
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: child),
      ),
    );
  }

  /// Opens the profile dropdown and taps its sign-out item.
  Future<void> tapLogout(WidgetTester tester) async {
    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MSAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text('auth.logout'));
    await tester.pumpAndSettle();
  }

  group('the dropdown sign-out', () {
    testWidgets('runs the hooks before a custom onLogout and its sign-out', (
      tester,
    ) async {
      MagicStarter.beforeLogout(() async => order.add('hook'));
      MagicStarter.useLogout(() async {
        order.add('onLogout');
        await Auth.logout();
      });

      await tapLogout(tester);

      expect(order, ['hook', 'onLogout', 'Auth.logout']);
    });

    testWidgets('runs the hooks once without a custom onLogout', (
      tester,
    ) async {
      MagicStarter.beforeLogout(() async => order.add('hook'));

      await tapLogout(tester);

      expect(order, ['hook', 'Auth.logout']);
    });
  });

  group('the controller sign-out', () {
    test('runs the hooks before Auth.logout, in registration order', () async {
      MagicStarter.beforeLogout(() async => order.add('hook'));
      MagicStarter.beforeLogout(() async => order.add('second hook'));

      await MagicStarterAuthController.instance.logout();

      expect(order, ['hook', 'second hook', 'Auth.logout']);
    });

    test('is not blocked by a hook that throws', () async {
      MagicStarter.beforeLogout(() async => throw StateError('release down'));
      MagicStarter.beforeLogout(() async => order.add('hook'));

      await MagicStarterAuthController.instance.logout();

      expect(order, ['hook', 'Auth.logout']);
      expect(
        log.entries.where(
          (entry) =>
              entry.level == 'error' && entry.message.contains('release down'),
        ),
        hasLength(1),
      );
    });

    testWidgets('is not trapped by a hook that never answers', (tester) async {
      MagicStarter.beforeLogout(() => Completer<void>().future);
      MagicStarter.beforeLogout(() async => order.add('hook'));

      unawaited(MagicStarterAuthController.instance.logout());
      await tester.pump(const Duration(seconds: 4));
      expect(order, isEmpty);

      await tester.pump(const Duration(seconds: 2));
      expect(order, ['hook', 'Auth.logout']);
    });
  });

  group('the default push release hook', () {
    Future<void> bootProvider() async {
      final provider = MagicStarterServiceProvider(MagicApp.instance);
      provider.register();
      await provider.boot();
    }

    test('is registered when push-state reporting is configured', () async {
      Magic.singleton('notifications', () => Notify.manager);
      Config.set('notifications.push_state.report_path', '/devices/push-state');
      Config.set(
        'notifications.push_state.release_path',
        '/devices/push-state/release',
      );

      await bootProvider();
      await bootProvider();

      expect(MagicStarter.manager.beforeLogoutHooks, [
        Notify.pushState.release,
      ]);
    });

    test('is not registered while push-state reporting is off', () async {
      Magic.singleton('notifications', () => Notify.manager);

      await bootProvider();

      expect(MagicStarter.manager.beforeLogoutHooks, isEmpty);
    });

    test('is not registered without the notifications package bound', () async {
      Config.set('notifications.push_state.report_path', '/devices/push-state');

      await bootProvider();

      expect(MagicStarter.manager.beforeLogoutHooks, isEmpty);
    });
  });
}
