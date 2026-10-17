import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Pins the shell id a host's own app group has to share with the starter's.
///
/// Magic merges route groups into one go_router `ShellRoute` only when they
/// carry the same `layoutId`. A group with another id, or none, becomes a
/// second shell, and every crossing between the two re-animates the whole
/// layout.
void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
  });

  test('the app id stays the literal existing hosts already use', () {
    expect(MagicStarterLayoutIds.app, 'app');
  });

  test('profile, team and notification groups land in one app layout', () {
    for (final String feature in ['teams', 'notifications']) {
      Config.set('magic_starter.features.$feature', true);
    }

    registerMagicStarterProfileRoutes();
    registerMagicStarterTeamRoutes();
    registerMagicStarterNotificationRoutes();

    final layouts = MagicRouter.instance.mergedLayouts;
    expect(layouts, hasLength(1));
    expect(layouts.single.id, MagicStarterLayoutIds.app);

    final paths = layouts.single.children.map((route) => route.path);
    expect(paths, contains(MagicStarterConfig.settingsHubRoute()));
    expect(paths, contains('${MagicStarterConfig.teamsPrefix()}/create'));
    expect(paths, contains(MagicStarterConfig.notificationsRoute()));
  });
}
