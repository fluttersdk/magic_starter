import 'package:magic/magic.dart';

import '../contracts/magic_starter_social_auth.dart';

/// The sentence to show for a social login refusal: the catalogue's
/// `social.<code>` line when it has one, else the bridge's own message, else
/// the generic `errors.unexpected`.
///
/// A cancelled flow has nothing to show; callers check
/// [MagicStarterSocialException.cancelled] before asking.
String socialFailureMessage(MagicStarterSocialException exception) {
  final key = 'social.${exception.code}';
  if (exception.code != null && Lang.has(key)) {
    return trans(key);
  }

  return exception.message.isNotEmpty
      ? exception.message
      : trans('errors.unexpected');
}
