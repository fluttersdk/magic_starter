import 'dart:math';

import 'package:magic/magic.dart';

import 'concerns/navigates_routes.dart';
import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';
import '../../models/magic_starter_auth_user.dart';

/// Controller managing guest authentication and device-ID-based upgrade flows.
///
/// Generates a persistent UUID v4 device identifier stored in [Vault] (secure
/// storage). On every guest login attempt the same UUID is reused, so the
/// backend can associate a returning guest with their previous session.
///
/// ### Typical usage
/// ```dart
/// await StarterGuestAuthController.instance.doGuestLogin();
/// ```
class StarterGuestAuthController extends MagicController
    with MagicStateMixin<bool>, ValidatesRequests, NavigatesRoutes {
  /// Singleton accessor — follows the Magic Framework controller pattern.
  static StarterGuestAuthController get instance =>
      Magic.findOrPut(StarterGuestAuthController.new);
  bool _isSubmitting = false;

  /// Vault key used to persist the guest device identifier across sessions.
  static const String _deviceIdKey = 'guest_device_id';

  // -------------------------------------------------------------------------
  // Public actions
  // -------------------------------------------------------------------------

  /// Authenticates the user as a guest using a persistent UUID v4 device ID.
  ///
  /// Steps:
  ///   1. Load existing device ID from Vault or generate a new UUID v4.
  ///   2. Persist the device ID in Vault for future app starts.
  ///   3. Send `POST /auth/guest` with the device ID.
  ///   4. Store the returned auth token via [Auth.login].
  ///   5. Navigate to the home route on success.
  Future<void> doGuestLogin() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      // 1. Load or generate a persistent UUID v4 device identifier.
      final existing = await Vault.get(_deviceIdKey);
      final deviceId = existing ?? _generateUuidV4();

      // 2. Persist the device ID for subsequent app launches.
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
        return;
      }

      // 4. Store the auth token and set the authenticated user.
      final responseData = response.data as Map<String, dynamic>?;
      final nestedData = responseData?['data'] as Map<String, dynamic>?;
      final token = nestedData?['token'] as String?;
      final userData = nestedData?['user'] as Map<String, dynamic>?;

      if (token != null) {
        await Auth.login(
          {'token': token},
          userData != null
              ? MagicStarter.createUser(userData)
              : MagicStarterAuthUser.fromMap(nestedData ?? {}),
        );
      }

      setSuccess(true);

      // 5. Navigate home.
      navigateTo(MagicStarterConfig.homeRoute());
    } catch (e, stackTrace) {
      Log.error('[StarterGuestAuthController.doGuestLogin] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
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
