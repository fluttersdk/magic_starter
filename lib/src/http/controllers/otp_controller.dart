import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';

/// Represents the two steps in the phone OTP authentication flow.
///
/// [phoneInput] — the user enters their phone number and requests an OTP.
/// [codeInput]  — the user enters the 6-digit code received via SMS.
enum OtpStep {
  /// Step 1: collect the phone number and send the OTP.
  phoneInput,

  /// Step 2: collect the 6-digit code and verify it.
  codeInput,
}

/// Controller managing the phone OTP authentication flow.
///
/// The flow has two steps:
///   1. [sendOtp] — POSTs the phone number to `/auth/otp/send`. On success,
///      advances to [OtpStep.codeInput] and stores the phone for step 2.
///   2. [verifyOtp] — POSTs phone + code to `/auth/otp/verify`. On success,
///      calls [Auth.login] with the returned token and navigates home.
///
/// Gated by [MagicStarterConfig.hasPhoneOtpFeatures].
class StarterOtpController extends MagicController
    with MagicStateMixin, ValidatesRequests {
  /// Singleton accessor via IoC container.
  static StarterOtpController get instance =>
      Magic.findOrPut(StarterOtpController.new);

  /// Submit-guard prevents concurrent requests.
  bool _isSubmitting = false;

  /// Current step in the OTP flow.
  OtpStep _step = OtpStep.phoneInput;

  /// The phone number supplied in step 1 — retained for the step 2 payload.
  String? _phoneNumber;

  /// Returns the current OTP flow step.
  OtpStep get step => _step;

  /// Returns the phone number captured during [sendOtp], or `null` if step 1
  /// has not been completed yet.
  String? get phoneNumber => _phoneNumber;

  /// Render OTP verify view via registry key.
  Widget otpVerify() => MagicStarter.view.make('auth.otp_verify');

  /// Sends an OTP code to [phone] via `POST /auth/otp/send`.
  ///
  /// On success: stores [phone] internally and transitions to
  /// [OtpStep.codeInput].
  /// On failure: sets error state; step remains [OtpStep.phoneInput].
  ///
  /// @param phone  E.164-formatted phone number (e.g. `+905301234567`).
  Future<void> sendOtp({required String phone}) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      // 1. Capture phone early — needed in step 2 even if user navigates away.
      _phoneNumber = phone;

      final response = await Http.post(
        '/auth/otp/send',
        data: {'phone': phone},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('magic_starter.otp.send_error'),
        );
        return;
      }

      // 2. Advance to code input step on success.
      _step = OtpStep.codeInput;
      setSuccess(null);
    } catch (e, stackTrace) {
      Log.error('[StarterOtpController.sendOtp] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Verifies the OTP [code] for [phone] via `POST /auth/otp/verify`.
  ///
  /// On success: calls [Auth.login] with the returned token and navigates to
  /// the configured home route.
  /// On failure: sets error state; step remains [OtpStep.codeInput].
  ///
  /// @param phone  E.164-formatted phone number — may be omitted to fall back
  ///               to the value stored by [sendOtp].
  /// @param code   The 6-digit OTP code received via SMS.
  Future<void> verifyOtp({
    required String phone,
    required String code,
  }) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      // 1. Prefer the caller-supplied phone; fall back to the stored value.
      final resolvedPhone = phone.isNotEmpty ? phone : (_phoneNumber ?? '');

      final response = await Http.post(
        '/auth/otp/verify',
        data: {
          'phone': resolvedPhone,
          'code': code,
        },
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('magic_starter.otp.verify_error'),
        );
        return;
      }

      // 2. Extract token from response and authenticate the user.
      final data = response.data as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      final userData = data?['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        await Auth.login(
          {
            'token': token,
          },
          MagicStarter.createUser(userData),
        );
      }

      // 3. Navigate home on successful authentication.
      setSuccess(data);
      _navigateTo(MagicStarterConfig.homeRoute());
    } catch (e, stackTrace) {
      Log.error('[StarterOtpController.verifyOtp] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Resets the flow back to [OtpStep.phoneInput].
  ///
  /// Clears any error state so the phone input step renders cleanly.
  void resetToPhoneInput() {
    _step = OtpStep.phoneInput;
    setSuccess(null);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _navigateTo(String path) {
    if (MagicRouter.instance.navigatorKey.currentContext != null) {
      MagicRoute.to(path);
    }
  }
}
