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
/// ```dart
/// MagicRoute.group(
///   middleware: ['auth'],
///   routes: () { /* protected routes */ },
/// );
/// ```
class EnsureAuthenticated extends MagicMiddleware {
  @override
  String? redirectTarget(String location) {
    // Guard the login route itself so the redirect can never loop: go_router
    // raises after more than five successive redirects.
    final String login = MagicStarterConfig.loginRoute();
    if (!Auth.check() && location != login) {
      return login;
    }
    return null;
  }
}
