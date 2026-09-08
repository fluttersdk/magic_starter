import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';

/// Shared navigation helper for Magic Starter controllers.
///
/// Provides a safe [navigateTo] method that checks for navigator context
/// before navigating. Extracted from duplicated `_navigateTo` methods
/// across [MagicStarterAuthController], [MagicStarterGuestAuthController],
/// and [MagicStarterOtpController].
mixin NavigatesRoutes {
  /// Navigate to [path] when a navigator context is available.
  ///
  /// Optionally accepts [query] parameters for the target route.
  /// No-ops silently when no navigator context exists (e.g. during tests
  /// or before the widget tree is mounted).
  void navigateTo(String path, {Map<String, String>? query}) {
    if (MagicRouter.instance.navigatorKey.currentContext == null) return;

    MagicRoute.to(path, query: query);
  }

  /// Navigate to wherever a signed-in user should land after authenticating.
  ///
  /// This is the ONLY post-auth navigation seam: every controller action
  /// that follows a successful login, registration, two-factor challenge,
  /// OTP verification or guest login must call this instead of navigating
  /// to [MagicStarterConfig.homeRoute] directly, or the deep-link-through-
  /// login flow below silently keeps sending everyone home.
  ///
  /// Pulls the URL `EnsureAuthenticated` recorded before bouncing the user
  /// to login (see [MagicRouter.pullIntendedUrl], a one-time read) and
  /// targets it when it is a well-formed in-app path (non-null, leading
  /// slash). Any other value, including no stored intent at all, falls
  /// back to [MagicStarterConfig.homeRoute]. The leading-slash check is
  /// defence in depth: `setIntendedUrl` is only ever called with a router
  /// location internally, so this guards against a value that should not
  /// be reachable rather than one that is.
  void navigateHome() {
    if (MagicRouter.instance.navigatorKey.currentContext == null) return;

    final String? intended = MagicRouter.instance.pullIntendedUrl();
    final bool hasValidIntent = intended != null && intended.startsWith('/');
    final String target = hasValidIntent
        ? intended
        : MagicStarterConfig.homeRoute();

    navigateTo(target);
  }
}
