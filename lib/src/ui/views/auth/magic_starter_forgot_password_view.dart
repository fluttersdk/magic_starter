import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_auth_controller.dart';
import '../../widgets/magic_starter_auth_form_card.dart';

class MagicStarterForgotPasswordView
    extends MagicStatefulView<MagicStarterAuthController> {
  const MagicStarterForgotPasswordView({super.key});

  @override
  State<MagicStarterForgotPasswordView> createState() =>
      _MagicStarterForgotPasswordViewState();
}

class _MagicStarterForgotPasswordViewState extends MagicStatefulViewState<
    MagicStarterAuthController, MagicStarterForgotPasswordView> {
  late final form = MagicFormData(
    {'email': ''},
    controller: controller,
  );

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() => form.dispose();

  Future<void> _submit() async {
    if (!form.validate()) return;
    await controller.doForgotPassword(email: form.get('email'));
  }

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (_) => _buildSuccess(context),
      onEmpty: _buildForm(context),
      onError: (message) => _buildForm(context, errorMessage: message),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final footerSlot = MagicStarter.view.buildSlot(
      'auth.forgot_password',
      'footer',
      context,
    );

    return MagicStarterAuthFormCard(
      title: trans('auth.forgot_password_title'),
      subtitle: trans('auth.forgot_password_subtitle'),
      child: WDiv(
        className: 'flex flex-col items-center gap-4',
        children: [
          WDiv(
            className:
                'w-16 h-16 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center',
            child: WIcon(
              Icons.check_circle_outline,
              className: 'text-[32px] text-green-600 dark:text-green-400',
            ),
          ),
          WText(
            trans('auth.reset_link_sent'),
            className: 'text-sm text-gray-600 dark:text-gray-400 text-center',
          ),
          const WSpacer(className: 'h-2'),
          WAnchor(
            onTap: () => MagicRoute.to('/auth/login'),
            child: WText(
              trans('auth.back_to_login'),
              className: MagicStarter.formTheme.linkClassName,
            ),
          ),
          if (footerSlot != null) ...[
            const WSpacer(className: 'h-2'),
            footerSlot,
          ],
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, {String? errorMessage}) {
    final isLoading = controller.isLoading;
    final headerSlot = MagicStarter.view.buildSlot(
      'auth.forgot_password',
      'header',
      context,
    );
    final footerSlot = MagicStarter.view.buildSlot(
      'auth.forgot_password',
      'footer',
      context,
    );

    return MagicStarterAuthFormCard(
      title: trans('auth.forgot_password_title'),
      subtitle: trans('auth.forgot_password_subtitle'),
      errorMessage: errorMessage,
      child: MagicForm(
        formData: form,
        child: WDiv(
          className: 'flex flex-col items-stretch',
          children: [
            if (headerSlot != null) ...[
              headerSlot,
              const WSpacer(className: 'h-4'),
            ],
            WFormInput(
              label: trans('attributes.email'),
              controller: form['email'],
              placeholder: trans('fields.email_placeholder'),
              type: InputType.email,
              validator: rules([Required(), Email()], field: 'email'),
              className: MagicStarter.formTheme.inputClassName,
              placeholderClassName: MagicStarter.formTheme.placeholderClassName,
              labelClassName: MagicStarter.formTheme.labelClassName,
            ),
            const WSpacer(className: 'h-6'),
            WButton(
              isLoading: isLoading,
              onTap: _submit,
              className: MagicStarter.formTheme.primaryButtonClassName,
              child: WText(
                trans('auth.send_reset_link'),
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
}
