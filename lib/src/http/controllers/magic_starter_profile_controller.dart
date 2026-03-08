import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';
import 'concerns/navigates_routes.dart';

/// Profile controller for Magic Starter plugin.
class MagicStarterProfileController extends MagicController
    with MagicStateMixin<bool>, ValidatesRequests, NavigatesRoutes {
  static MagicStarterProfileController get instance =>
      Magic.findOrPut(MagicStarterProfileController.new);
  bool _isSubmitting = false;

  /// Whether controller notifications are temporarily suppressed.
  ///
  /// When `true`, [notifyListeners] calls are silently discarded.
  /// Used by [withoutNotifying] to prevent full-page rebuilds when
  /// form-level loading state (via [MagicFormData.process]) is sufficient.
  bool _suppressNotifications = false;

  /// Render profile settings view via registry key.
  Widget profile() => MagicStarter.view.make('profile.settings');

  /// Execute [action] without triggering UI notifications.
  ///
  /// All [setLoading], [setSuccess], [setError], [handleApiError],
  /// and [clearErrors] calls within [action] will update internal
  /// state but skip [notifyListeners], preventing full-page rebuilds.
  ///
  /// Use when form-level loading (via [MagicFormData.process]) already
  /// drives the submit button's loading indicator.
  ///
  /// ```dart
  /// await form.process(() => controller.withoutNotifying(
  ///     () => controller.doUpdateProfile(name: 'Alice', email: 'a@b.com'),
  /// ));
  /// ```
  Future<T> withoutNotifying<T>(Future<T> Function() action) async {
    _suppressNotifications = true;
    try {
      return await action();
    } finally {
      _suppressNotifications = false;
    }
  }

  @override
  void notifyListeners() {
    if (_suppressNotifications) return;
    super.notifyListeners();
  }

  /// Update profile information.
  Future<bool> doUpdateProfile({
    required String name,
    required String email,
    String? phone,
    String? timezone,
    String? language,
    String? password,
    String? passwordConfirmation,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final data = <String, dynamic>{
        'name': name,
        'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (timezone != null && timezone.isNotEmpty) 'timezone': timezone,
        if (language != null && language.isNotEmpty) 'language': language,
        if (password != null && password.isNotEmpty) 'password': password,
        if (passwordConfirmation != null && passwordConfirmation.isNotEmpty)
          'password_confirmation': passwordConfirmation,
      };

      final response = await Http.put(
        '/user/profile',
        data: data,
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.update_failed'),
        );
        return false;
      }

      await Auth.restore();
      Magic.toast(trans('profile.updated'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doUpdateProfile] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Update password.
  Future<bool> doUpdatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.put(
        '/user/password',
        data: {
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.password_update_failed'),
        );
        return false;
      }

      Magic.toast(trans('profile.password_updated'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doUpdatePassword] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Delete user account.
  Future<bool> doDeleteAccount({required String password}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/user',
        data: {'_method': 'DELETE', 'password': password},
      );
      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.delete_failed'),
        );
        return false;
      }

      await Auth.logout();
      navigateTo(MagicStarterConfig.loginRoute());
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doDeleteAccount] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Update profile photo.
  Future<bool> doUpdateProfilePhoto({required MagicFile file}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.upload(
        "/user/profile-photo",
        data: {},
        files: {"photo": file},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.photo_update_failed'),
        );
        return false;
      }

      await Auth.restore();
      Magic.toast(trans('profile.photo_updated'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doUpdateProfilePhoto] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Delete profile photo.
  Future<bool> doDeleteProfilePhoto() async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.delete(
        '/user/profile-photo',
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.photo_delete_failed'),
        );
        return false;
      }

      await Auth.restore();
      Magic.toast(trans('profile.photo_deleted'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doDeleteProfilePhoto] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Enables two-factor authentication for the current user.
  ///
  /// Requires the current account [password] for confirmation.
  ///
  /// Returns a map containing [secret], [qr_url], [qr_svg], and [recovery_codes]
  /// on success, or null on failure.
  Future<Map<String, dynamic>?> doEnableTwoFactor(
      {required String password}) async {
    if (_isSubmitting) return null;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-authentication',
        data: {
          'password': password,
        },
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.two_factor_enable_failed'),
        );
        if (!isError) {
          setError(trans('profile.two_factor_enable_failed'));
        }
        return null;
      }

      final data = response.data?['data'] as Map<String, dynamic>?;
      setSuccess(true);
      return data;
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doEnableTwoFactor] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return null;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Confirms two-factor authentication setup with the provided OTP code.
  Future<bool> doConfirmTwoFactor({required String code}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-authentication/confirm',
        data: {'code': code},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.two_factor_confirm_failed'),
        );
        return false;
      }

      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doConfirmTwoFactor] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Disables two-factor authentication.
  ///
  /// Requires the current account [password] for sudo-mode confirmation.
  /// The password is sent directly to the endpoint (no separate confirm call).
  Future<bool> doDisableTwoFactor({required String password}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-authentication',
        data: {
          '_method': 'DELETE',
          'password': password,
        },
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.two_factor_disable_failed'),
        );
        return false;
      }

      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doDisableTwoFactor] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Retrieves the current two-factor authentication recovery codes.
  ///
  /// Requires the current account [password] for sudo-mode confirmation.
  /// Uses `POST /two-factor-recovery-codes/show` with password in body.
  Future<List<String>?> getRecoveryCodes({required String password}) async {
    if (_isSubmitting) return null;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-recovery-codes/show',
        data: {
          'password': password,
        },
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.two_factor_recovery_codes_fetch_failed'),
        );
        return null;
      }

      final data = response.data?['data'] as List<dynamic>?;
      setSuccess(true);
      return data?.map((e) => e.toString()).toList();
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.getRecoveryCodes] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return null;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Regenerates two-factor authentication recovery codes.
  ///
  /// Requires the current account [password] for sudo-mode confirmation.
  /// The password is sent directly to the endpoint (no separate confirm call).
  Future<List<String>?> doRegenerateRecoveryCodes(
      {required String password}) async {
    if (_isSubmitting) return null;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-recovery-codes',
        data: {
          'password': password,
        },
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback:
              trans('profile.two_factor_recovery_codes_regenerate_failed'),
        );
        return null;
      }

      final data = response.data?['data'] as List<dynamic>?;
      setSuccess(true);
      return data?.map((e) => e.toString()).toList();
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doRegenerateRecoveryCodes] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return null;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Retrieves the current browser sessions.
  Future<List<Map<String, dynamic>>?> getSessions() async {
    if (!MagicStarterConfig.hasSessionsFeatures()) return null;
    if (_isSubmitting) return null;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.get('/sessions');

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.sessions_fetch_error'),
        );
        return null;
      }

      final data = response.data?['data'] as List<dynamic>?;
      setSuccess(true);
      return data?.map((e) => e as Map<String, dynamic>).toList();
    } catch (e, stackTrace) {
      Log.error('[MagicStarterProfileController.getSessions] $e\n$stackTrace');
      setError(trans('profile.sessions_fetch_error'));
      return null;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Revokes a specific browser session by its token ID.
  ///
  /// Requires the user's current password for sudo-mode validation.
  Future<bool> doRevokeSession({
    required String tokenId,
    required String password,
  }) async {
    if (!MagicStarterConfig.hasSessionsFeatures()) return false;
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/sessions/$tokenId',
        data: {'_method': 'DELETE', 'password': password},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.session_revoke_error'),
        );
        return false;
      }

      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doRevokeSession] $e\n$stackTrace');
      setError(trans('profile.session_revoke_error'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Revokes all other browser sessions except the current one. Requires current password.
  Future<bool> doRevokeOtherSessions({required String password}) async {
    if (!MagicStarterConfig.hasSessionsFeatures()) return false;
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/sessions/other',
        data: {'_method': 'DELETE', 'password': password},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.other_sessions_revoke_error'),
        );
        return false;
      }

      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.doRevokeOtherSessions] $e\n$stackTrace');
      setError(trans('profile.other_sessions_revoke_error'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Sends a verification email to the authenticated user's email address.
  ///
  /// Calls `POST /email/verification-notification`. On success, shows a toast
  /// confirmation and sets success state. On error, delegates to
  /// [handleApiError] with a localised fallback message.
  Future<void> sendEmailVerification() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();

    try {
      final response = await Http.post(
        '/email/verification-notification',
        data: {},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('magic_starter.email_verification.send_error'),
        );
        return;
      }

      setSuccess(true);
      Magic.toast(trans('magic_starter.email_verification.sent'));
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterProfileController.sendEmailVerification] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Returns whether the authenticated user's email address has been verified.
  ///
  /// Reads `email_verified_at` from the current [Auth.user()] — returns `true`
  /// only when the field resolves to a non-null, non-empty string.
  bool get isEmailVerified {
    final user = Auth.user();
    if (user == null) return false;
    final verifiedAt = user.get<String?>('email_verified_at');
    return verifiedAt != null && verifiedAt.isNotEmpty;
  }

  /// Whether the authenticated user has two-factor authentication enabled.
  ///
  /// Reads [two_factor_enabled] from the current [Auth.user()] model.
  /// Returns [false] when no user is authenticated or the field is absent.
  bool get isTwoFactorEnabled {
    final user = Auth.user();
    if (user == null) return false;
    return user.get<bool>('two_factor_enabled') ?? false;
  }
}
