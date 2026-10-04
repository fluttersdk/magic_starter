import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import 'navigates_routes.dart';

/// The one way a sign-in concludes, shared by every path that receives a token.
///
/// Password login, social sign-in, the two-factor challenge, the OTP verify
/// and guest login all end here, because the backend answers each of them the
/// same way and cancels a scheduled account deletion on every token it issues:
/// a path that concluded on its own would sign the user in without telling
/// them their deletion was called off.
mixin CompletesSignIn on NavigatesRoutes {
  /// Concludes a sign-in from the backend's response [body].
  ///
  /// A two-factor answer (`two_factor: true`, at the top level or under
  /// `data`) opens the challenge with its `two_factor_token`. A session
  /// (`data.token` and `data.user`) is logged in, announced with a toast when
  /// `data.deletion_cancelled` is true, and sent home.
  ///
  /// Returns `false` when [body] is neither, leaving the caller to report it;
  /// the caller also owns its controller state.
  Future<bool> completeSignIn(Map<String, dynamic>? body) async {
    final data = body?['data'] as Map<String, dynamic>?;

    // 1. A confirmed second factor: the challenge, never a session.
    if (body?['two_factor'] == true || data?['two_factor'] == true) {
      final twoFactorToken =
          body?['two_factor_token'] as String? ??
          data?['two_factor_token'] as String?;
      navigateTo(
        MagicStarterConfig.twoFactorChallengeRoute(),
        query: twoFactorToken != null
            ? {'two_factor_token': twoFactorToken}
            : null,
      );

      return true;
    }

    final token = data?['token'] as String?;
    final userData = data?['user'] as Map<String, dynamic>?;
    if (token == null || userData == null) {
      return false;
    }

    // 2. The session, then the one thing it did the user did not ask for.
    await Auth.login({'token': token}, MagicStarter.createUser(userData));
    if (data?['deletion_cancelled'] == true) {
      Magic.toast(trans('social.deletion_cancelled'));
    }

    // 3. Home, or wherever the user was headed before login.
    navigateHome();

    return true;
  }
}
