import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';

/// Auth controller for Magic Starter plugin.
class StarterAuthController extends MagicController
    with MagicStateMixin<bool>, ValidatesRequests {
  static StarterAuthController get instance =>
      Magic.findOrPut(StarterAuthController.new);

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
  Future<void> doLogin({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'remember_me': rememberMe,
        },
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('auth.login_failed'),
        );
        return;
      }

      final data = response['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      final userData = data?['user'] as Map<String, dynamic>?;

      if (token == null || userData == null) {
        setError(trans('auth.invalid_response'));
        return;
      }

      await Auth.login({'token': token}, MagicStarter.createUser(userData));
      setSuccess(true);
      _navigateTo(MagicStarterConfig.homeRoute());
    } catch (e, stackTrace) {
      Log.error('[StarterAuthController.doLogin] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Register a new user.
  Future<void> doRegister({
    required String name,
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
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
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
        await Auth.login({'token': token}, MagicStarter.createUser(userData));
        setSuccess(true);
        _navigateTo(MagicStarterConfig.homeRoute());
        return;
      }

      setSuccess(true);
      _navigateTo(MagicStarterConfig.loginRoute());
    } catch (e, stackTrace) {
      Log.error('[StarterAuthController.doRegister] $e\n$stackTrace');
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
      Log.error('[StarterAuthController.doForgotPassword] $e\n$stackTrace');
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
      Log.error('[StarterAuthController.doResetPassword] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Logout user.
  Future<void> logout() async {
    await Auth.logout();
    _navigateTo(MagicStarterConfig.loginRoute());
  }

  void _navigateTo(String path) {
    if (MagicRouter.instance.navigatorKey.currentContext != null) {
      MagicRoute.to(path);
    }
  }
}
