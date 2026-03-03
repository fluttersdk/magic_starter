import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/magic_starter_notification_controller.dart';

/// Registers notification routes provided by Magic Starter plugin.
///
/// Routes are only registered when `magic_starter.features.notifications`
/// is enabled. When disabled, calling this function is a no-op.
void registerMagicStarterNotificationRoutes() {
  if (!MagicStarterConfig.hasNotificationFeatures()) return;

  MagicRoute.group(
    middleware: ['auth'],
    layoutId: 'app',
    layout: (child) => MagicStarter.view.makeLayout('layout.app', child: child),
    routes: () {
      MagicRoute.page(
        MagicStarterConfig.notificationsRoute(),
        MagicStarterNotificationController.instance.index,
      ).transition(RouteTransition.none);
      MagicRoute.page(
        MagicStarterConfig.notificationPreferencesRoute(),
        MagicStarterNotificationController.instance.preferences,
      ).transition(RouteTransition.none);
    },
  );
}
