import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../http/controllers/auth_controller.dart';
import '../../widgets/auth_form_card.dart';

class MagicStarterForgotPasswordView
    extends MagicStatefulView<StarterAuthController> {
  const MagicStarterForgotPasswordView({super.key});

  @override
  State<MagicStarterForgotPasswordView> createState() =>
      _MagicStarterForgotPasswordViewState();
}

class _MagicStarterForgotPasswordViewState extends MagicStatefulViewState<
    StarterAuthController, MagicStarterForgotPasswordView> {
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
      (_) => _buildSuccess(),
      onEmpty: _buildForm(),
      onError: (message) => _buildForm(errorMessage: message),
    );
  }

  Widget _buildSuccess() {
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
              className: 'text-sm font-semibold text-primary',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm({String? errorMessage}) {
    final isLoading = controller.isLoading;

    return MagicStarterAuthFormCard(
      title: trans('auth.forgot_password_title'),
      subtitle: trans('auth.forgot_password_subtitle'),
      errorMessage: errorMessage,
      child: MagicForm(
        formData: form,
        child: WDiv(
          className: 'flex flex-col items-stretch',
          children: [
            WFormInput(
              label: trans('attributes.email'),
              controller: form['email'],
              placeholder: trans('fields.email_placeholder'),
              type: InputType.email,
              validator: rules([Required(), Email()], field: 'email'),
              className: 'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
              placeholderClassName: 'text-gray-400 dark:text-gray-500',
              labelClassName: 'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            ),
            const WSpacer(className: 'h-6'),
            WButton(
              isLoading: isLoading,
              onTap: _submit,
              className: 'w-full bg-primary hover:bg-primary/80 text-white text-base font-semibold py-3 rounded-lg',
              child: WText(trans('auth.send_reset_link'),
                  className: 'text-center'),
            ),
            const WSpacer(className: 'h-6'),
            WAnchor(
              onTap: () => MagicRoute.to('/auth/login'),
              child: WDiv(
                className: 'flex flex-row justify-center',
                child: WText(
                  trans('auth.back_to_login'),
                  className: 'text-sm font-semibold text-primary',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
