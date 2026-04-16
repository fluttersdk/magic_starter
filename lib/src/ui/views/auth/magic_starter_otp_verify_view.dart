import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_otp_controller.dart';
import '../../widgets/magic_starter_auth_form_card.dart';

/// Multi-step view for phone OTP authentication.
///
/// Renders two distinct steps:
///   - **Step 1** ([OtpStep.phoneInput]): user enters their E.164 phone
///     number and taps "Send Code" to trigger [MagicStarterOtpController.sendOtp].
///   - **Step 2** ([OtpStep.codeInput]): user enters the 6-digit code
///     received via SMS and taps "Verify" to trigger
///     [MagicStarterOtpController.verifyOtp]. A "Back" link lets the user return
///     to step 1 via [MagicStarterOtpController.resetToPhoneInput].
///
/// Gated at the route level by [MagicStarterConfig.hasPhoneOtpFeatures].
/// Must be registered in the ViewRegistry under the `auth.otp_verify` key.
class MagicStarterOtpVerifyView
    extends MagicStatefulView<MagicStarterOtpController> {
  const MagicStarterOtpVerifyView({super.key});

  @override
  State<MagicStarterOtpVerifyView> createState() =>
      _MagicStarterOtpVerifyViewState();
}

class _MagicStarterOtpVerifyViewState extends MagicStatefulViewState<
    MagicStarterOtpController, MagicStarterOtpVerifyView> {
  // -------------------------------------------------------------------------
  // Form state — both forms declared upfront; only the active one is rendered.
  // -------------------------------------------------------------------------

  /// Step 1 form: phone number field.
  late final _phoneForm = MagicFormData(
    {'phone': ''},
    controller: controller,
  );

  /// Step 2 form: 6-digit code field.
  late final _codeForm = MagicFormData(
    {'code': ''},
    controller: controller,
  );

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() {
    _phoneForm.dispose();
    _codeForm.dispose();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Re-render whenever controller state changes (loading / error / step).
    return controller.renderState(
      (_) => _buildCurrentStep(context),
      onEmpty: _buildCurrentStep(context),
      onError: (message) => _buildCurrentStep(context, errorMessage: message),
    );
  }

  /// Delegates to the correct step widget based on [MagicStarterOtpController.step].
  Widget _buildCurrentStep(BuildContext context, {String? errorMessage}) {
    return switch (controller.step) {
      OtpStep.phoneInput =>
        _buildPhoneInputStep(context, errorMessage: errorMessage),
      OtpStep.codeInput =>
        _buildCodeInputStep(context, errorMessage: errorMessage),
    };
  }

  // -------------------------------------------------------------------------
  // Step 1 — Phone input
  // -------------------------------------------------------------------------

  /// Builds the phone-number entry form wrapped in the guest layout card.
  Widget _buildPhoneInputStep(BuildContext context, {String? errorMessage}) {
    final isLoading = controller.isLoading;
    final headerSlot = MagicStarter.view.buildSlot(
      'auth.otp_verify',
      'header',
      context,
    );
    final footerSlot = MagicStarter.view.buildSlot(
      'auth.otp_verify',
      'footer',
      context,
    );

    return MagicStarterAuthFormCard(
      title: trans('magic_starter.otp.phone_title'),
      subtitle: trans('magic_starter.otp.phone_subtitle'),
      errorMessage: errorMessage,
      child: MagicForm(
        formData: _phoneForm,
        child: WDiv(
          className: 'flex flex-col items-stretch',
          children: [
            if (headerSlot != null) ...[
              headerSlot,
              const WSpacer(className: 'h-4'),
            ],
            WFormInput(
              label: trans('attributes.phone'),
              controller: _phoneForm['phone'],
              placeholder: trans('fields.phone_placeholder'),
              type: InputType.text,
              validator: rules([Required()], field: 'phone'),
              className: MagicStarter.formTheme.inputClassName,
              placeholderClassName: MagicStarter.formTheme.placeholderClassName,
              labelClassName: MagicStarter.formTheme.labelClassName,
            ),
            const WSpacer(className: 'h-6'),
            WButton(
              isLoading: isLoading,
              onTap: _submitPhone,
              className: MagicStarter.formTheme.primaryButtonClassName,
              child: WText(
                trans('magic_starter.otp.send_code_button'),
                className: 'text-center',
              ),
            ),
            const WSpacer(className: 'h-6'),
            WAnchor(
              onTap: () => MagicRoute.to('/auth/login'),
              child: WDiv(
                className: 'flex flex-row justify-center',
                child: WText(
                  trans('auth.back_to_login'),
                  className: MagicStarter.formTheme.linkClassName,
                ),
              ),
            ),
            if (footerSlot != null) ...[
              const WSpacer(className: 'h-4'),
              footerSlot,
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 2 — Code input
  // -------------------------------------------------------------------------

  /// Builds the 6-digit code entry form wrapped in the guest layout card.
  Widget _buildCodeInputStep(BuildContext context, {String? errorMessage}) {
    final isLoading = controller.isLoading;
    final headerSlot = MagicStarter.view.buildSlot(
      'auth.otp_verify',
      'header',
      context,
    );
    final footerSlot = MagicStarter.view.buildSlot(
      'auth.otp_verify',
      'footer',
      context,
    );

    return MagicStarterAuthFormCard(
      title: trans('magic_starter.otp.code_title'),
      subtitle: trans('magic_starter.otp.code_subtitle'),
      errorMessage: errorMessage,
      child: MagicForm(
        formData: _codeForm,
        child: WDiv(
          className: 'flex flex-col items-stretch',
          children: [
            if (headerSlot != null) ...[
              headerSlot,
              const WSpacer(className: 'h-4'),
            ],
            WFormInput(
              label: trans('magic_starter.otp.code_label'),
              controller: _codeForm['code'],
              placeholder: trans('fields.otp_placeholder'),
              type: InputType.number,
              inputFormatters: [LengthLimitingTextInputFormatter(6)],
              validator: rules(
                [Required(), Min(6), Max(6)],
                field: 'code',
              ),
              className: MagicStarter.formTheme.inputClassName,
              placeholderClassName: MagicStarter.formTheme.placeholderClassName,
              labelClassName: MagicStarter.formTheme.labelClassName,
            ),
            const WSpacer(className: 'h-6'),
            WButton(
              isLoading: isLoading,
              onTap: _submitCode,
              className: MagicStarter.formTheme.primaryButtonClassName,
              child: WText(
                trans('magic_starter.otp.verify_button'),
                className: 'text-center',
              ),
            ),
            const WSpacer(className: 'h-4'),
            WAnchor(
              onTap: _resendCode,
              child: WDiv(
                className: 'flex flex-row justify-center',
                child: WText(
                  trans('magic_starter.otp.resend_link'),
                  className: 'text-sm font-medium text-gray-500 '
                      'dark:text-gray-400 hover:text-primary '
                      'dark:hover:text-primary',
                ),
              ),
            ),
            const WSpacer(className: 'h-2'),
            WAnchor(
              onTap: controller.resetToPhoneInput,
              child: WDiv(
                className: 'flex flex-row justify-center',
                child: WText(
                  trans('magic_starter.otp.back_button'),
                  className: MagicStarter.formTheme.linkClassName,
                ),
              ),
            ),
            if (footerSlot != null) ...[
              const WSpacer(className: 'h-4'),
              footerSlot,
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  /// Validates the phone form and invokes [MagicStarterOtpController.sendOtp].
  Future<void> _submitPhone() async {
    if (!_phoneForm.validate()) return;
    await controller.sendOtp(phone: _phoneForm.get('phone'));
  }

  /// Validates the code form and invokes [MagicStarterOtpController.verifyOtp].
  ///
  /// The phone is sourced from the controller (stored during [_submitPhone]).
  Future<void> _submitCode() async {
    if (!_codeForm.validate()) return;
    await controller.verifyOtp(
      phone: controller.phoneNumber ?? '',
      code: _codeForm.get('code'),
    );
  }

  /// Resets to phone input step so the user can request a new code.
  Future<void> _resendCode() async {
    controller.resetToPhoneInput();
  }
}
