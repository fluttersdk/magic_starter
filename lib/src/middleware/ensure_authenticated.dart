import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';

/// Middleware that redirects unauthenticated users to the login page.
///
/// Register as the `'auth'` alias so every gated route group (profile,
/// teams, notifications) redirects an unauthenticated visitor. It overrides
/// [redirectTarget] (a pre-build synchronous redirect) instead of [handle]
/// (a post-build remount): the router evaluates the redirect inside its
/// `redirect` callback before any page builds, so an unauthenticated boot
/// lands on the login route and the gated page never mounts.
///
/// Before bouncing to login it records [location] via
/// [MagicRouter.setIntendedUrl], so `NavigatesRoutes.navigateHome` can send
/// the user back there once they authenticate. Nothing is recorded for the
/// login route itself (nothing to return to) or for any other guest-only
/// route registered in `auth_routes.dart` (register, forgot-password,
/// reset-password, two-factor-challenge, otp): a visitor bounced off one of
/// those cannot use it as a post-login destination either.
///
/// **Known limit**: [redirectTarget] receives `state.matchedLocation` (see
/// `magic_router.dart`'s `_handleRedirect`), which carries no query string,
/// so a recorded intent loses any `?token=...` the original link carried.
///
/// ```dart
/// MagicRoute.group(
///   middleware: ['auth'],
///   routes: () { /* protected routes */ },
/// );
/// ```
class EnsureAuthenticated extends MagicMiddleware {
  /// Path suffixes (under the configured auth prefix) that are themselves
  /// guest-only screens: see `auth_routes.dart` for the route registrations
  /// this mirrors.
  static const List<String> _guestRouteSuffixes = <String>[
    '/register',
    '/forgot-password',
    '/reset-password',
    '/two-factor-challenge',
    '/otp',
  ];

  @override
  String? redirectTarget(String location) {
    if (Auth.check()) return null;

    // Guard the login route itself so the redirect can never loop: go_router
    // raises after more than five successive redirects.
    final String login = MagicStarterConfig.loginRoute();
    if (location == login) return null;

    if (!_isGuestRoute(location)) {
      MagicRouter.instance.setIntendedUrl(location);
    }

    return login;
  }

  /// Whether [location] is one of the guest-only auth routes registered in
  /// `auth_routes.dart` (the login route itself is handled by the caller).
  bool _isGuestRoute(String location) {
    final String authPrefix = MagicStarterConfig.authPrefix();
    return _guestRouteSuffixes.any(
      (suffix) => location == '$authPrefix$suffix',
    );
  }
}
