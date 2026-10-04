import 'package:flutter/widgets.dart';

/// The bridge between the starter's screens and an app's social login.
///
/// The starter owns the screens and what a sign-in concludes (a session, a
/// two-factor challenge, a cancelled deletion); the bridge owns the provider
/// SDKs and the backend calls. An app registers one through
/// `MagicStarter.useSocialAuth`, which keeps this package free of any
/// dependency on a social login package.
///
/// Every failure surfaces as a [MagicStarterSocialException].
abstract class MagicStarterSocialAuth {
  /// The providers to offer, in display order (`google`, `apple`, ...).
  List<String> providers();

  /// The provider's display name, such as `Google`.
  String label(String provider);

  /// The provider's mark, shown beside [label].
  Widget icon(String provider);

  /// Signs in with [provider] and answers the backend's body untouched.
  ///
  /// The body is a session (`{data: {user, token}}`, plus
  /// `data.deletion_cancelled` when the sign-in cancelled a scheduled
  /// deletion) or a challenge (`{two_factor: true, two_factor_token}`).
  ///
  /// Called synchronously from the user's tap, with no await before it, so a
  /// web implementation can still open its popup. A newer call supersedes a
  /// pending one.
  Future<Map<String, dynamic>> signIn(String provider);

  /// Starts linking [provider] to the signed-in account and answers the call
  /// that finishes it.
  ///
  /// [proof] is the step-up proof the backend asks of a connect; it is minted
  /// fresh for every call and empty for a guest. Whatever needs the network
  /// before the provider opens (a link ticket) happens here, so the returned
  /// call opens the provider before its first await. On the web the starter
  /// runs it from a fresh user tap, because a popup opened after an await is
  /// blocked; elsewhere it runs it at once. It answers the backend's body
  /// (`{data: {provider, email}}`).
  Future<Future<Map<String, dynamic>> Function()> beginConnect(
    String provider,
    Map<String, String> proof,
  );

  /// Re-authenticates the signed-in user with [provider] and answers the
  /// confirmation token the backend issued.
  Future<String> confirm(String provider);

  /// Signs out of every provider SDK that keeps a session of its own.
  Future<void> signOut();
}

/// A social flow that did not conclude.
///
/// [cancelled] marks the user backing out, which the starter shows nothing
/// for. Otherwise [code] is the backend's refusal code (`social_email_taken`,
/// `flow_expired`, ...) when there is one; the starter shows its
/// `social.<code>` sentence and falls back to [message].
class MagicStarterSocialException implements Exception {
  /// Creates a failure; with no arguments it is an uncoded one.
  const MagicStarterSocialException({
    this.code,
    this.message = '',
    this.cancelled = false,
  });

  /// The backend's stable refusal code, or `null` for a client-side failure.
  final String? code;

  /// A sentence to show when the catalogue has none for [code].
  final String message;

  /// Whether the user backed out of the flow.
  final bool cancelled;

  @override
  String toString() =>
      'MagicStarterSocialException(code: $code, cancelled: $cancelled, '
      'message: $message)';
}
