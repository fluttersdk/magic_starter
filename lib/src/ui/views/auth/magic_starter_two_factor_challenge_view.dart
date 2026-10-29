import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart' show ButtonSize, MSButton;

import '../../../facades/magic_starter.dart';
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

class _MagicStarterTwoFactorChallengeViewState
    extends
        MagicStatefulViewState<
          MagicStarterAuthController,
          MagicStarterTwoFactorChallengeView
        > {
  bool _useRecoveryCode = false;
  final TextEditingController _codeController = TextEditingController();

  /// The `two_factor_token` of this page's own route, read by
  /// [didChangeDependencies] before the first build.
  late String _token;

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  // The route state cannot be read in initState, so the token is read here.
  // Reading again on a later call is safe: the context-bound reader answers
  // this page's own route, where the static reader named the page the router
  // built last, which is another page's once routes sit in two layout shells.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _token =
        MagicRouter.instance.queryParameterOf(context, 'two_factor_token') ??
        '';
  }

  @override
  void onClose() {
    _codeController.dispose();
  }

  Future<void> _submit() async {
    if (_useRecoveryCode) {
      await controller.doTwoFactorChallenge(
        twoFactorToken: _token,
        recoveryCode: _codeController.text.trim(),
      );
    } else {
      await controller.doTwoFactorChallenge(
        twoFactorToken: _token,
        code: _codeController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (_) => _buildContent(context),
      onEmpty: _buildContent(context),
      onError: (message) => _buildContent(context, errorMessage: message),
    );
  }

  Widget _buildContent(BuildContext context, {String? errorMessage}) {
    final isLoading = controller.isLoading;
    final headerSlot = MagicStarter.view.buildSlot(
      'auth.two_factor_challenge',
      'header',
      context,
    );
    final footerSlot = MagicStarter.view.buildSlot(
      'auth.two_factor_challenge',
      'footer',
      context,
    );

    return MagicStarterAuthFormCard(
      title: trans('auth.two_factor_challenge'),
      subtitle: _useRecoveryCode
          ? trans('auth.two_factor_recovery_description')
          : trans('auth.two_factor_code_description'),
      errorMessage: errorMessage,
      child: WDiv(
        className: 'flex flex-col gap-6',
        children: [
          ?headerSlot,
          // MSInput
          WFormInput(
            controller: _codeController,
            label: _useRecoveryCode
                ? trans('auth.recovery_code')
                : trans('auth.authentication_code'),
            placeholder: _useRecoveryCode ? 'xxxxx-xxxxx' : '123456',
            className: MagicStarter.formTheme.inputClassName,
            placeholderClassName: MagicStarter.formTheme.placeholderClassName,
            labelClassName: MagicStarter.formTheme.labelClassName,
          ),
          // Submit button
          MSButton(
            isLoading: isLoading,
            onPressed: _submit,
            size: ButtonSize.lg,
            className: MagicStarter.formTheme.primaryButtonClassName,
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
                  className: MagicStarter.formTheme.linkClassName,
                ),
              ),
            ],
          ),
          ?footerSlot,
        ],
      ),
    );
  }
}
