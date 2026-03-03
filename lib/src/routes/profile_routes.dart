import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/magic_starter_profile_controller.dart';

/// Registers profile routes provided by Magic Starter plugin.
void registerMagicStarterProfileRoutes() {
  MagicRoute.group(
    middleware: ['auth'],
    layoutId: 'app',
    layout: (child) => MagicStarter.view.makeLayout('layout.app', child: child),
    routes: () {
      MagicRoute.page(
        MagicStarterConfig.profileRoute(),
        MagicStarterProfileController.instance.profile,
      ).transition(RouteTransition.none);
    },
  );
}
