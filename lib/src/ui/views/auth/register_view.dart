import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/auth_controller.dart';
import '../../widgets/auth_form_card.dart';
import '../../widgets/social_login_divider.dart';

class MagicStarterRegisterView
    extends MagicStatefulView<StarterAuthController> {
  const MagicStarterRegisterView({super.key});

  @override
  State<MagicStarterRegisterView> createState() =>
      _MagicStarterRegisterViewState();
}

class _MagicStarterRegisterViewState extends MagicStatefulViewState<
    StarterAuthController, MagicStarterRegisterView> {
  late final form = MagicFormData(
    {
      'name': '',
      'email': '',
      'password': '',
      'password_confirmation': '',
    },
    controller: controller,
  );

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() => form.dispose();

  Future<void> _submit() async {
    if (!form.validate()) return;

    await controller.doRegister(
      name: form.get('name'),
      email: form.get('email'),
      password: form.get('password'),
      passwordConfirmation: form.get('password_confirmation'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (_) => _buildForm(),
      onEmpty: _buildForm(),
      onError: (message) => _buildForm(errorMessage: message),
    );
  }

  Widget _buildForm({String? errorMessage}) {
    final isLoading = controller.isLoading;

    return MagicStarterAuthFormCard(
      title: trans('auth.register_title'),
      subtitle: trans('auth.register_subtitle'),
      errorMessage: errorMessage,
      child: MagicForm(
        formData: form,
        child: WDiv(
          className: 'flex flex-col items-stretch',
          children: [
            // Name
            WFormInput(
              label: trans('attributes.name'),
              controller: form['name'],
              placeholder: trans('fields.name_placeholder'),
              validator: rules([Required(), Min(2)], field: 'name'),
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
              placeholderClassName: 'text-gray-400 dark:text-gray-500',
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            ),
            const WSpacer(className: 'h-4'),

            // Email
            WFormInput(
              label: trans('attributes.email'),
              controller: form['email'],
              placeholder: trans('fields.email_placeholder'),
              type: InputType.email,
              validator: rules([Required(), Email()], field: 'email'),
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
              placeholderClassName: 'text-gray-400 dark:text-gray-500',
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            ),
            const WSpacer(className: 'h-4'),

            // Password
            WFormInput(
              label: trans('attributes.password'),
              controller: form['password'],
              placeholder: trans('fields.password_placeholder'),
              type: _obscurePassword ? InputType.password : InputType.text,
              validator: rules([Required(), Min(8)], field: 'password'),
              suffix: WAnchor(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: WIcon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
              placeholderClassName: 'text-gray-400 dark:text-gray-500',
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            ),
            const WSpacer(className: 'h-4'),

            // Password Confirmation
            WFormInput(
              label: trans('attributes.password_confirmation'),
              controller: form['password_confirmation'],
              placeholder: trans('fields.password_confirmation_placeholder'),
              type: _obscureConfirmation ? InputType.password : InputType.text,
              validator: rules([Required()], field: 'password_confirmation'),
              suffix: WAnchor(
                onTap: () => setState(
                    () => _obscureConfirmation = !_obscureConfirmation),
                child: WIcon(
                  _obscureConfirmation
                      ? Icons.visibility
                      : Icons.visibility_off,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
              placeholderClassName: 'text-gray-400 dark:text-gray-500',
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            ),
            const WSpacer(className: 'h-6'),

            // Submit
            WButton(
              isLoading: isLoading,
              onTap: _submit,
              className:
                  'w-full bg-primary hover:bg-primary/80 text-white text-base font-semibold py-3 rounded-lg',
              child:
                  WText(trans('auth.register_title'), className: 'text-center'),
            ),

            // Social login slot
            if (MagicStarterConfig.hasSocialLoginFeatures() &&
                MagicStarter.hasSocialLogin) ...[
              const MagicStarterSocialDivider(),
              MagicStarter.socialLoginBuilder!(context, isLoading),
            ],

            // Login link
            const WSpacer(className: 'h-6'),
            WAnchor(
              onTap: () => MagicRoute.to('/auth/login'),
              child: WDiv(
                className: 'flex flex-row justify-center gap-1',
                children: [
                  WText(
                    trans('auth.already_have_account'),
                    className: 'text-sm text-gray-500 dark:text-gray-400',
                  ),
                  WText(
                    trans('auth.sign_in'),
                    className: 'text-sm font-semibold text-primary',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
