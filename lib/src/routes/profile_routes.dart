import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../http/controllers/profile_controller.dart';

/// Registers profile routes provided by Magic Starter plugin.
void registerMagicStarterProfileRoutes() {
  MagicRoute.group(
    middleware: ['auth'],
    routes: () {
      MagicRoute.page(
        MagicStarterConfig.profileRoute(),
        ProfileController.instance.profile,
      ).transition(RouteTransition.none);
    },
  );
}
