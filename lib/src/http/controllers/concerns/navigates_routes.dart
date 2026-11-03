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
    // `//host/path` is protocol-relative: it starts with a slash and is a
    // different ORIGIN, so the leading-slash test alone lets it through.
    // Nothing reachable can store one today, since only a router location is
    // ever recorded, which is exactly why the check is cheap to keep.
    final bool hasValidIntent =
        intended != null &&
        intended.startsWith('/') &&
        !intended.startsWith('//');
    final String target = hasValidIntent
        ? intended
        : MagicStarterConfig.homeRoute();

    navigateTo(target);
  }
}

/// The `next` a link carries into a sign-in: where [NavigatesRoutes.navigateHome]
/// lands once the visitor is signed in.
///
/// A `next` arrives in a url anyone can craft, so it is held to one in-app path
/// before it becomes the intended url: exactly one leading slash (`//host` is
/// another origin), at most [maxLength] characters, no backslash (a browser
/// reads `/\host` as `//host`), no whitespace, separator (`\p{Z}`) or other
/// character (`\p{C}`: controls, format characters such as U+202E, private
/// use, unassigned), and no `..` path segment, percent-encoded or not. The
/// same rule as the backend's `SameAppPath`.
abstract final class MagicStarterNextPath {
  /// The longest `next` accepted.
  static const int maxLength = 512;

  static final RegExp _forbidden = RegExp(r'[\\\s\p{Z}\p{C}]', unicode: true);

  /// [value] when it is a safe in-app path, otherwise `null`.
  static String? parse(String? value) {
    if (value == null || value.length > maxLength) return null;
    if (!value.startsWith('/') || value.startsWith('//')) return null;
    if (_forbidden.hasMatch(value)) return null;

    final String path = value.split(RegExp('[?#]')).first;
    final bool climbs = path
        .split('/')
        .any(
          (String segment) =>
              segment.toLowerCase().replaceAll('%2e', '.') == '..',
        );

    return climbs ? null : value;
  }

  /// Stores [value] as the router's intended url when [parse] accepts it, so
  /// the next sign-in or sign-up of any kind ends there. Anything else is
  /// ignored silently and leaves a stored intent alone.
  static void remember(String? value) {
    final String? next = parse(value);
    if (next == null) return;

    MagicRouter.instance.setIntendedUrl(next);
  }
}
