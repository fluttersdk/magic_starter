import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/notification_controller.dart';

/// Registers notification routes provided by Magic Starter plugin.
void registerMagicStarterNotificationRoutes() {
  MagicRoute.group(
    middleware: ['auth'],
    layoutId: 'app',
    layout: (child) => MagicStarter.view.makeLayout('layout.app', child: child),
    routes: () {
      MagicRoute.page(
        MagicStarterConfig.notificationsRoute(),
        StarterNotificationController.instance.index,
      ).transition(RouteTransition.none);
      MagicRoute.page(
        MagicStarterConfig.notificationPreferencesRoute(),
        StarterNotificationController.instance.preferences,
      ).transition(RouteTransition.none);
    },
  );
}
