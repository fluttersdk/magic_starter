import 'dart:math';

import 'package:magic/magic.dart';

import 'concerns/completes_sign_in.dart';
import 'concerns/navigates_routes.dart';

/// Controller managing guest authentication and device-ID-based upgrade flows.
///
/// Generates a persistent UUID v4 device identifier stored in [Vault] (secure
/// storage). On every guest login attempt the same UUID is reused, so the
/// backend can associate a returning guest with their previous session.
///
/// ### Typical usage
/// ```dart
/// await MagicStarterGuestAuthController.instance.doGuestLogin();
///
/// // A host opening one in the background, the viewer left where they are:
/// final hasSession =
///     await MagicStarterGuestAuthController.instance.openGuestSession();
/// ```
class MagicStarterGuestAuthController extends MagicController
    with
        MagicStateMixin<bool>,
        ValidatesRequests,
        NavigatesRoutes,
        CompletesSignIn {
  /// Singleton accessor — follows the Magic Framework controller pattern.
  static MagicStarterGuestAuthController get instance =>
      Magic.findOrPut(MagicStarterGuestAuthController.new);

  /// Vault key used to persist the guest device identifier across sessions.
  static const String _deviceIdKey = 'guest_device_id';

  /// The open in flight, shared by every caller until it settles.
  Future<bool>? _opening;

  // -------------------------------------------------------------------------
  // Public actions
  // -------------------------------------------------------------------------

  /// The login screen's "Continue as guest": opens a guest session through
  /// [openGuestSession], then goes home, or wherever the visitor was headed.
  ///
  /// A user who is already a guest goes home without a request. The login
  /// page lets a guest in (it is where a guest signs in to an account), so
  /// "Continue as guest" is that guest's way back.
  Future<void> doGuestLogin() async {
    if (!await openGuestSession()) return;

    navigateHome();
  }

  /// Opens a guest session in the background, without moving the viewer.
  ///
  /// For a host that needs a session before anyone asks for one, at launch
  /// for example. Resolves `true` when a session exists afterwards and
  /// `false` when none could be opened, with the reason in the controller's
  /// error state; never throws.
  ///
  /// A session already held is kept and no request is sent: a guest's,
  /// because a second `POST /auth/guest` revokes every token the returning
  /// guest holds, including one a host keeps to claim the guest's data at
  /// sign-in; and an account's, signed in or only stored (a cold boot on a
  /// dead link keeps the token without loading its user), because a guest
  /// never replaces an account.
  ///
  /// Concurrent callers share the one request in flight and its result. The
  /// share ends when it settles, so a call after a failure tries again.
  Future<bool> openGuestSession() {
    return _opening ??= _openGuestSession().whenComplete(() {
      _opening = null;
    });
  }

  /// The single attempt [openGuestSession] shares between its callers.
  Future<bool> _openGuestSession() async {
    try {
      // 1. Keep any session already held; see [openGuestSession].
      if (Auth.check() || await Auth.hasToken()) return true;

      setLoading();
      clearErrors();

      // 2. Load or generate a persistent UUID v4 device identifier, and
      //    persist it so the backend recognises a returning guest.
      final deviceId = await Vault.get(_deviceIdKey) ?? _generateUuidV4();
      await Vault.put(_deviceIdKey, deviceId);

      // 3. Authenticate as a guest against the API.
      final response = await Http.post(
        '/auth/guest',
        data: {'device_id': deviceId},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('magic_starter.auth.guest_login_error'),
        );
        return false;
      }

      // 4. Conclude the sign-in through the path every token takes, leaving
      //    navigation to the caller.
      final concluded = await completeSignIn(
        response.data as Map<String, dynamic>?,
        navigate: false,
      );
      if (!concluded) {
        setError(trans('magic_starter.auth.guest_login_error'));
        return false;
      }

      setSuccess(true);

      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterGuestAuthController.openGuestSession] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));

      return false;
    }
  }

  /// Returns the persisted guest device ID, or `null` if not yet stored.
  ///
  /// Useful for displaying or debugging the current guest identity.
  Future<String?> getStoredDeviceId() => Vault.get(_deviceIdKey);

  /// Returns `true` when the currently authenticated user is a guest.
  ///
  /// Reads `is_guest` from the authenticated user model provided by the host.
  bool get isGuestUser {
    return Auth.user()?.get<bool>('is_guest') ?? false;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Generates a cryptographically random UUID v4 string.
  ///
  /// Uses [Random.secure] — no external package required.
  /// Format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` where `y` is `8`, `9`,
  /// `a`, or `b`.
  String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

    // Set version bits: version 4.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;

    // Set variant bits: 10xx (RFC 4122).
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    return [
      bytes.sublist(0, 4).map(hex).join(),
      bytes.sublist(4, 6).map(hex).join(),
      bytes.sublist(6, 8).map(hex).join(),
      bytes.sublist(8, 10).map(hex).join(),
      bytes.sublist(10, 16).map(hex).join(),
    ].join('-');
  }
}
