import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

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
}
