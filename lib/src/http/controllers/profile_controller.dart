import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';

/// Profile controller for Magic Starter plugin.
class StarterProfileController extends MagicController
    with MagicStateMixin<bool>, ValidatesRequests {
  static StarterProfileController get instance =>
      Magic.findOrPut(StarterProfileController.new);
  bool _isSubmitting = false;

  /// Render profile settings view via registry key.
  Widget profile() => MagicStarter.view.make('profile.settings');

  /// Update profile information.
  Future<bool> doUpdateProfile({
    required String name,
    required String email,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.put(
        '/user/profile',
        data: {'name': name, 'email': email},
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
      Log.error('[StarterProfileController.doUpdateProfile] $e\n$stackTrace');
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
      Log.error('[StarterProfileController.doUpdatePassword] $e\n$stackTrace');
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
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error('[StarterProfileController.doDeleteAccount] $e\n$stackTrace');
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
          '[StarterProfileController.doUpdateProfilePhoto] $e\n$stackTrace');
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
          '[StarterProfileController.doDeleteProfilePhoto] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }
  /// Enables two-factor authentication for the current user.
  ///
  /// Returns a map containing [secret], [qr_url], [qr_svg], and [recovery_codes]
  /// on success, or null on failure.
  Future<Map<String, dynamic>?> doEnableTwoFactor() async {
    if (_isSubmitting) return null;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post('/two-factor-authentication', data: {});

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.two_factor_enable_failed'),
        );
        return null;
      }

      final data = response.data?['data'] as Map<String, dynamic>?;
      setSuccess(true);
      return data;
    } catch (e, stackTrace) {
      Log.error('[StarterProfileController.doEnableTwoFactor] $e\n$stackTrace');
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
      Log.error('[StarterProfileController.doConfirmTwoFactor] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Disables two-factor authentication. Requires current password.
  Future<bool> doDisableTwoFactor({required String password}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-authentication',
        data: {'_method': 'DELETE', 'password': password},
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
      Log.error('[StarterProfileController.doDisableTwoFactor] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Retrieves the current two-factor authentication recovery codes.
  Future<List<String>?> getRecoveryCodes() async {
    setLoading();
    clearErrors();

    try {
      final response = await Http.get('/two-factor-recovery-codes');

      if (!response.successful) {
        setError(trans('profile.two_factor_recovery_codes_fetch_failed'));
        return null;
      }

      final data = response.data?['data'] as List<dynamic>?;
      setSuccess(true);
      return data?.map((e) => e.toString()).toList();
    } catch (e, stackTrace) {
      Log.error('[StarterProfileController.getRecoveryCodes] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return null;
    }
  }

  /// Regenerates two-factor authentication recovery codes.
  Future<List<String>?> doRegenerateRecoveryCodes() async {
    if (_isSubmitting) return null;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post('/two-factor-recovery-codes', data: {});

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.two_factor_recovery_codes_regenerate_failed'),
        );
        return null;
      }

      final data = response.data?['data'] as List<dynamic>?;
      setSuccess(true);
      return data?.map((e) => e.toString()).toList();
    } catch (e, stackTrace) {
      Log.error('[StarterProfileController.doRegenerateRecoveryCodes] $e\n$stackTrace');
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
      Log.error('[StarterProfileController.getSessions] $e\n$stackTrace');
      setError(trans('profile.sessions_fetch_error'));
      return null;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Revokes a specific browser session by its token ID.
  Future<bool> doRevokeSession({required String tokenId}) async {
    if (!MagicStarterConfig.hasSessionsFeatures()) return false;
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.delete('/sessions/$tokenId');

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
      Log.error('[StarterProfileController.doRevokeSession] $e\n$stackTrace');
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
      Log.error('[StarterProfileController.doRevokeOtherSessions] $e\n$stackTrace');
      setError(trans('profile.other_sessions_revoke_error'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }
}
