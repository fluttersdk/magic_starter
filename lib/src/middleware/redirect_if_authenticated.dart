import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';

/// Middleware that redirects authenticated users away from guest-only pages.
///
/// Register as the `'guest'` alias so the starter's own auth route group
/// (login, registration, password reset, two-factor challenge, OTP) sends an
/// already signed-in visitor onward instead of re-rendering the login form.
/// It overrides [redirectTarget] (a pre-build synchronous redirect) instead
/// of [handle] (a post-build remount): an already authenticated user hitting
/// an auth page resolves to the home route before the guest page builds, so
/// the destination mounts exactly once.
///
/// ```dart
/// MagicRoute.group(
///   middleware: ['guest'],
///   routes: () { /* auth pages */ },
/// );
/// ```
class RedirectIfAuthenticated extends MagicMiddleware {
  @override
  String? redirectTarget(String location) {
    // Guard the home route itself so the redirect can never loop: go_router
    // raises after more than five successive redirects.
    final String home = MagicStarterConfig.homeRoute();
    if (Auth.check() && !_isGuestAccount() && location != home) {
      return home;
    }
    return null;
  }

  /// Whether the signed-in user is a guest session rather than an account.
  ///
  /// A guest is authenticated, so `Auth.check()` alone sent it home from the
  /// login and registration pages, which are exactly where a guest becomes an
  /// account. The same `is_guest` flag the `starter.delete-account` ability
  /// reads.
  bool _isGuestAccount() {
    return Auth.user()?.get<bool>('is_guest') == true;
  }
}
