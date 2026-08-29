import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/magic_starter_auth_controller.dart';
import '../http/controllers/magic_starter_otp_controller.dart';

/// Registers auth routes provided by Magic Starter plugin.
///
/// Every page carries a `.title()`, because a route without one falls back to
/// the bare app name and a browser tab then reads `Acme` on the login screen,
/// the register screen and the password reset alike. The keys live under
/// `magic_starter.titles.*` and, like every other key this package references,
/// are supplied by the CONSUMER's catalogue; `assets/stubs/install/en.stub`
/// carries them for a fresh install, and an existing app merges them once.
void registerMagicStarterAuthRoutes() {
  MagicRoute.group(
    prefix: MagicStarterConfig.authPrefix(),
    middleware: ['guest'],
    layout: (child) =>
        MagicStarter.view.makeLayout('layout.guest', child: child),
    routes: () {
      MagicRoute.page(
        '/login',
        MagicStarterAuthController.instance.login,
      ).title('magic_starter.titles.login').transition(RouteTransition.none);

      if (MagicStarterConfig.hasRegistrationFeatures()) {
        MagicRoute.page(
              '/register',
              MagicStarterAuthController.instance.register,
            )
            .title('magic_starter.titles.register')
            .transition(RouteTransition.none);
      }

      MagicRoute.page(
            '/forgot-password',
            MagicStarterAuthController.instance.forgotPassword,
          )
          .title('magic_starter.titles.forgot_password')
          .transition(RouteTransition.none);

      MagicRoute.page(
            '/reset-password',
            MagicStarterAuthController.instance.resetPassword,
          )
          .title('magic_starter.titles.reset_password')
          .transition(RouteTransition.none);

      if (MagicStarterConfig.hasTwoFactorFeatures()) {
        MagicRoute.page(
              '/two-factor-challenge',
              MagicStarterAuthController.instance.twoFactorChallenge,
            )
            .title('magic_starter.titles.two_factor_challenge')
            .transition(RouteTransition.none);
      }

      if (MagicStarterConfig.hasPhoneOtpFeatures()) {
        MagicRoute.page(
          '/otp',
          MagicStarterOtpController.instance.otpVerify,
        ).title('magic_starter.titles.otp').transition(RouteTransition.none);
      }
    },
  );
}
