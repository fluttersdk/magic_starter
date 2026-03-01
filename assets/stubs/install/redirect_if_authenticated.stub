import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Middleware that redirects authenticated users away from guest-only pages.
///
/// Use this in guest-only route groups (auth pages):
///
/// ```dart
/// MagicRoute.group(
///   middleware: [RedirectIfAuthenticated()],
///   routes: () { /* auth pages */ },
/// );
/// ```
class RedirectIfAuthenticated extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    if (Auth.check()) {
      MagicRoute.to(MagicStarterConfig.homeRoute());
      return;
    }
    next();
  }
}
