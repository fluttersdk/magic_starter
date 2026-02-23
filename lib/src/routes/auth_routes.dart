import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/auth_controller.dart';

/// Registers auth routes provided by Magic Starter plugin.
void registerMagicStarterAuthRoutes() {
  MagicRoute.group(
    prefix: MagicStarterConfig.authPrefix(),
    middleware: ['guest'],
    layout: (child) =>
        MagicStarter.view.makeLayout('layout.guest', child: child),
    routes: () {
      MagicRoute.page('/login', AuthController.instance.login)
          .transition(RouteTransition.none);

      if (MagicStarterConfig.hasRegistrationFeatures()) {
        MagicRoute.page('/register', AuthController.instance.register)
            .transition(RouteTransition.none);
      }

      MagicRoute.page(
        '/forgot-password',
        AuthController.instance.forgotPassword,
      ).transition(RouteTransition.none);

      MagicRoute.page(
        '/reset-password',
        AuthController.instance.resetPassword,
      ).transition(RouteTransition.none);
    },
  );
}
