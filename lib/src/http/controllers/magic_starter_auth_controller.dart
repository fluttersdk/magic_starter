import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';

import 'concerns/navigates_routes.dart';
import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';

/// Auth controller for Magic Starter plugin.
///
/// Supports 3 identity modes for login and registration:
///   - Email-only (default): `auth.email=true`, `auth.phone=false`
///   - Phone-only: `auth.email=false`, `auth.phone=true`
///   - Both: `auth.email=true`, `auth.phone=true` — caller selects by passing the
///     populated field; phone takes precedence when non-empty.
class MagicStarterAuthController extends MagicController
    with MagicStateMixin<bool>, ValidatesRequests, NavigatesRoutes {
  static MagicStarterAuthController get instance =>
      Magic.findOrPut(MagicStarterAuthController.new);

  bool _isSubmitting = false;

  /// Render login view via registry key.
  Widget login() => MagicStarter.view.make('auth.login');

  /// Render register view via registry key.
  Widget register() => MagicStarter.view.make('auth.register');

  /// Render forgot password view via registry key.
  Widget forgotPassword() => MagicStarter.view.make('auth.forgot_password');

  /// Render reset password view via registry key.
  Widget resetPassword() => MagicStarter.view.make('auth.reset_password');

  /// Render two-factor challenge view via registry key.
  Widget twoFactorChallenge() =>
      MagicStarter.view.make('auth.two_factor_challenge');

  /// Login user with API credentials.
  ///
  /// Builds the identity payload dynamically based on [MagicStarterConfig]:
  ///   - Email-only mode → `email` field is sent.
  ///   - Phone-only mode → `phone` field is sent.
  ///   - Both mode → `phone` takes precedence when non-empty; otherwise `email`.
  ///
  /// At least one of [email] or [phone] must be provided depending on the
  /// active identity mode. Providing neither in the applicable mode is a
  /// programming error and will result in an incomplete payload.
  Future<void> doLogin({
    String? email,
    String? phone,
    required String password,
    bool rememberMe = false,
  }) async {
    if (_isSubmitting) return;

    // Input validation
    if (password.isEmpty) {
      setError(trans('validation.required', {'attribute': 'password'}));
      return;
    }

    final hasEmail = email?.isNotEmpty ?? false;
    final hasPhone = phone?.isNotEmpty ?? false;

    if (!hasEmail && !hasPhone) {
      setError(trans('auth.login_failed'));
      return;
    }

    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      // 1. Build identity payload based on configured identity mode.
      final Map<String, dynamic> payload = {
        'password': password,
        'remember_me': rememberMe,
      };

      _applyIdentityToPayload(
        payload,
        email: email,
        phone: phone,
      );

      final response = await Http.post(
        '/auth/login',
        data: payload,
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('auth.login_failed'),
        );
        return;
      }

      // 2. Check if server requires 2FA — navigate to challenge without logging in.
      final responseData = response.data as Map<String, dynamic>?;
      final nestedData = responseData?['data'] as Map<String, dynamic>?;
      if (responseData?['two_factor'] == true ||
          nestedData?['two_factor'] == true) {
        final twoFactorToken = responseData?['two_factor_token'] as String? ??
            nestedData?['two_factor_token'] as String?;
        navigateTo(
          MagicStarterConfig.twoFactorChallengeRoute(),
          query: twoFactorToken != null
              ? {'two_factor_token': twoFactorToken}
              : null,
        );
        return;
      }

      final token = nestedData?['token'] as String?;
      final userData = nestedData?['user'] as Map<String, dynamic>?;
      if (token == null || userData == null) {
        setError(trans('auth.invalid_response'));
        return;
      }

      // 3. Authenticate the user and navigate home.
      await Auth.login({'token': token}, MagicStarter.createUser(userData));
      setSuccess(true);
      navigateTo(MagicStarterConfig.homeRoute());
    } on TimeoutException catch (e, stackTrace) {
      Log.error(
          '[MagicStarterAuthController.doLogin] Timeout: $e\n$stackTrace');
      setError(trans('errors.network_timeout'));
    } on SocketException catch (e, stackTrace) {
      Log.error(
          '[MagicStarterAuthController.doLogin] Network error: $e\n$stackTrace');
      setError(trans('errors.network_error'));
    } catch (e, stackTrace) {
      Log.error('[MagicStarterAuthController.doLogin] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Register a new user.
  ///
  /// Builds the identity payload dynamically based on [MagicStarterConfig]:
  ///   - Email-only mode → `email` is sent.
  ///   - Phone-only mode → `phone` is sent.
  ///   - Both mode → sends both `email` and `phone` when non-empty.
  Future<void> doRegister({
    required String name,
    String? email,
    String? phone,
    bool subscribeNewsletter = false,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      // 1. Build identity payload based on configured identity mode.
      final Map<String, dynamic> payload = {
        'name': name,
        'password': password,
        'password_confirmation': passwordConfirmation,
      };

      _applyIdentityToPayload(
        payload,
        email: email,
        phone: phone,
      );

      // 2. Include newsletter subscription flag when feature is active.
      if (MagicStarterConfig.hasNewsletterFeatures() && subscribeNewsletter) {
        payload['subscribe_newsletter'] = true;
      }

      final response = await Http.post(
        '/auth/login',
        data: payload,
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('auth.register_failed'),
        );
        return;
      }

      final data = response['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      final userData = data?['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        // 3. Auto-login when the server returns credentials immediately.
        await Auth.login({'token': token}, MagicStarter.createUser(userData));
        setSuccess(true);
        navigateTo(MagicStarterConfig.homeRoute());
        return;
      }

      // 4. No credentials returned — e.g. email-verification flow.
      setSuccess(true);
      navigateTo(MagicStarterConfig.loginRoute());
    } catch (e, stackTrace) {
      Log.error('[MagicStarterAuthController.doRegister] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Request a password reset link.
  Future<void> doForgotPassword({required String email}) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/auth/forgot-password',
        data: {'email': email},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('auth.reset_link_failed'),
        );
        return;
      }

      setSuccess(true);
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterAuthController.doForgotPassword] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Reset password with token.
  Future<void> doResetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/auth/reset-password',
        data: {
          'token': token,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('auth.password_reset_failed'),
        );
        return;
      }

      setSuccess(true);
    } catch (e, stackTrace) {
      Log.error('[MagicStarterAuthController.doResetPassword] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Completes the two-factor authentication challenge.
  ///
  /// Exactly one of [code] (OTP from authenticator) or [recoveryCode]
  /// (one of the user's recovery codes) must be non-null.
  ///
  /// @param twoFactorToken The encrypted token received from [doLogin].
  /// @param code           TOTP code from authenticator app (6 digits).
  /// @param recoveryCode   Recovery code (alphanumeric with hyphens).
  Future<void> doTwoFactorChallenge({
    required String twoFactorToken,
    String? code,
    String? recoveryCode,
  }) async {
    assert(
      (code == null) != (recoveryCode == null),
      'Exactly one of code or recoveryCode must be provided.',
    );
    if (_isSubmitting) return;
    _isSubmitting = true;

    setLoading();
    clearErrors();

    try {
      final payload = <String, dynamic>{
        'two_factor_token': twoFactorToken,
      };
      if (code != null) {
        payload['code'] = code;
      } else {
        payload['recovery_code'] = recoveryCode;
      }

      final response = await Http.post(
        '/auth/two-factor-challenge',
        data: payload,
      );

      if (!response.successful) {
        handleApiError(response, fallback: trans('auth.challenge_failed'));
        return;
      }

      // 1. Extract auth data from successful challenge response.
      final data = response.data?['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      final userData = data?['user'] as Map<String, dynamic>?;

      if (token == null || userData == null) {
        setError(trans('auth.challenge_failed'));
        return;
      }

      // 2. Log the user in and navigate to home.
      await Auth.login({'token': token}, MagicStarter.createUser(userData));
      setSuccess(true);
      navigateTo(MagicStarterConfig.homeRoute());
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterAuthController.doTwoFactorChallenge] $e\n$stackTrace');
      setError(trans('auth.challenge_failed'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Logout user.
  ///
  /// 1. Stop notification services when the feature is active.
  /// 2. Clear authentication tokens and navigate to login.
  Future<void> logout() async {
    // 1. Stop notification services when the feature is active.
    if (MagicStarterConfig.hasNotificationFeatures()) {
      try {
        await Notify.logoutPush();
        Notify.stopPolling();
      } catch (e, stackTrace) {
        Log.error(
          '[MagicStarterAuthController.logout] '
          'Notification cleanup failed: $e\n$stackTrace',
        );
      }
    }

    // 2. Clear authentication tokens and navigate to login.
    await Auth.logout();
    navigateTo(MagicStarterConfig.loginRoute());
  }

  /// Applies the correct identity fields (email and/or phone) to [payload]
  /// based on the active [MagicStarterConfig] identity mode.
  ///
  /// Mode resolution:
  ///   1. Email-only (`emailIdentity=true`, `phoneIdentity=false`) → adds `email`.
  ///   2. Phone-only (`emailIdentity=false`, `phoneIdentity=true`) → adds `phone`.
  ///   3. Both → sends every non-empty field so the backend receives both.
  void _applyIdentityToPayload(
    Map<String, dynamic> payload, {
    String? email,
    String? phone,
  }) {
    final emailMode = MagicStarterConfig.emailIdentity();
    final phoneMode = MagicStarterConfig.phoneIdentity();

    if (emailMode && !phoneMode) {
      // Email-only mode.
      payload['email'] = email ?? '';
    } else if (!emailMode && phoneMode) {
      // Phone-only mode.
      payload['phone'] = phone ?? '';
    } else {
      // Both mode — send every non-empty identity field.
      final resolvedEmail = email ?? '';
      final resolvedPhone = phone ?? '';

      if (resolvedEmail.isNotEmpty) {
        payload['email'] = resolvedEmail;
      }
      if (resolvedPhone.isNotEmpty) {
        payload['phone'] = resolvedPhone;
      }
    }
  }
}
