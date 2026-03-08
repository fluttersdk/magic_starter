import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/magic_starter_auth_controller.dart';
import '../http/controllers/magic_starter_otp_controller.dart';

/// Registers auth routes provided by Magic Starter plugin.
void registerMagicStarterAuthRoutes() {
  MagicRoute.group(
    prefix: MagicStarterConfig.authPrefix(),
    middleware: ['guest'],
    layout: (child) =>
        MagicStarter.view.makeLayout('layout.guest', child: child),
    routes: () {
      MagicRoute.page('/login', MagicStarterAuthController.instance.login)
          .transition(RouteTransition.none);

      if (MagicStarterConfig.hasRegistrationFeatures()) {
        MagicRoute.page(
                '/register', MagicStarterAuthController.instance.register)
            .transition(RouteTransition.none);
      }

      MagicRoute.page(
        '/forgot-password',
        MagicStarterAuthController.instance.forgotPassword,
      ).transition(RouteTransition.none);

      MagicRoute.page(
        '/reset-password',
        MagicStarterAuthController.instance.resetPassword,
      ).transition(RouteTransition.none);

      if (MagicStarterConfig.hasTwoFactorFeatures()) {
        MagicRoute.page(
          '/two-factor-challenge',
          MagicStarterAuthController.instance.twoFactorChallenge,
        ).transition(RouteTransition.none);
      }

      if (MagicStarterConfig.hasPhoneOtpFeatures()) {
        MagicRoute.page(
          '/otp',
          MagicStarterOtpController.instance.otpVerify,
        ).transition(RouteTransition.none);
      }
    },
  );
}
