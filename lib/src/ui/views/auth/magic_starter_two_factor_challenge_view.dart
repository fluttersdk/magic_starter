import 'dart:async';
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import '../../../http/controllers/magic_starter_auth_controller.dart';
import '../../widgets/magic_starter_auth_form_card.dart';

/// The Two-Factor Authentication challenge page.
///
/// Rendered after [MagicStarterAuthController.doLogin] detects a `two_factor: true`
/// response. The encrypted `two_factor_token` is received via the route's
/// query parameter `two_factor_token`.
///
/// Supports two modes:
/// - **OTP mode** (default): enter 6-digit TOTP code from authenticator app.
/// - **Recovery code mode**: enter a single-use alphanumeric recovery code.
class MagicStarterTwoFactorChallengeView
    extends MagicStatefulView<MagicStarterAuthController> {
  const MagicStarterTwoFactorChallengeView({super.key});

  @override
  State<MagicStarterTwoFactorChallengeView> createState() =>
      _MagicStarterTwoFactorChallengeViewState();
}

class _MagicStarterTwoFactorChallengeViewState extends MagicStatefulViewState<
    MagicStarterAuthController, MagicStarterTwoFactorChallengeView> {
  bool _useRecoveryCode = false;
  final TextEditingController _codeController = TextEditingController();

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() {
    _codeController.dispose();
  }

  Future<void> _submit() async {
    final token = MagicRouter.instance.queryParameter('two_factor_token') ?? '';
    if (_useRecoveryCode) {
      await controller.doTwoFactorChallenge(
        twoFactorToken: token,
        recoveryCode: _codeController.text.trim(),
      );
    } else {
      await controller.doTwoFactorChallenge(
        twoFactorToken: token,
        code: _codeController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (_) => _buildContent(),
      onEmpty: _buildContent(),
      onError: (message) => _buildContent(errorMessage: message),
    );
  }

  Widget _buildContent({String? errorMessage}) {
    final isLoading = controller.isLoading;

    return MagicStarterAuthFormCard(
      title: trans('auth.two_factor_challenge'),
      subtitle: _useRecoveryCode
          ? trans('auth.two_factor_recovery_description')
          : trans('auth.two_factor_code_description'),
      errorMessage: errorMessage,
      child: WDiv(
        className: 'flex flex-col gap-6',
        children: [
          // Input
          WFormInput(
            controller: _codeController,
            label: _useRecoveryCode
                ? trans('auth.recovery_code')
                : trans('auth.authentication_code'),
            placeholder: _useRecoveryCode ? 'xxxxx-xxxxx' : '123456',
            className:
                'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
            placeholderClassName: 'text-gray-400 dark:text-gray-500',
            labelClassName:
                'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
          ),
          // Submit button
          WButton(
            isLoading: isLoading,
            onTap: _submit,
            className:
                'w-full bg-primary hover:bg-primary/80 text-white text-base font-semibold py-3 rounded-lg flex items-center justify-center',
            child: WText(trans('auth.verify'), className: 'text-center'),
          ),
          // Toggle link
          WDiv(
            className: 'flex flex-row justify-center',
            children: [
              WAnchor(
                onTap: () => setState(() {
                  _useRecoveryCode = !_useRecoveryCode;
                  _codeController.clear();
                }),
                child: WText(
                  _useRecoveryCode
                      ? trans('auth.use_authentication_code')
                      : trans('auth.use_recovery_code'),
                  className:
                      'text-sm font-medium text-primary hover:underline cursor-pointer',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}