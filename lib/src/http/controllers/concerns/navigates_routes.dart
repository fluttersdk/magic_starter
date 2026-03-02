import 'package:magic/magic.dart';

/// Shared navigation helper for Magic Starter controllers.
///
/// Provides a safe [navigateTo] method that checks for navigator context
/// before navigating. Extracted from duplicated `_navigateTo` methods
/// across [StarterAuthController], [StarterGuestAuthController],
/// and [StarterOtpController].
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
}
