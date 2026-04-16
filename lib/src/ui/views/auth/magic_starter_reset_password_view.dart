import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_auth_controller.dart';
import '../../widgets/magic_starter_auth_form_card.dart';

class MagicStarterResetPasswordView
    extends MagicStatefulView<MagicStarterAuthController> {
  const MagicStarterResetPasswordView({super.key});

  @override
  State<MagicStarterResetPasswordView> createState() =>
      _MagicStarterResetPasswordViewState();
}

class _MagicStarterResetPasswordViewState extends MagicStatefulViewState<
    MagicStarterAuthController, MagicStarterResetPasswordView> {
  late final _token = MagicRouter.instance.pathParameter('token') ?? '';
  late final form = MagicFormData(
    {
      'email': '',
      'password': '',
      'password_confirmation': '',
    },
    controller: controller,
  );

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  static const _iconVisible = Icons.visibility;
  static const _iconHidden = Icons.visibility_off;

  @override
  void onInit() {
    final email = MagicRouter.instance.queryParameter('email');
    if (email != null && email.isNotEmpty) {
      form.set('email', email);
    }
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() => form.dispose();

  Future<void> _submit() async {
    if (!form.validate()) return;

    await controller.doResetPassword(
      token: _token,
      email: form.get('email'),
      password: form.get('password'),
      passwordConfirmation: form.get('password_confirmation'),
    );
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
      'auth.reset_password',
      'footer',
      context,
    );

    return MagicStarterAuthFormCard(
      title: trans('auth.reset_password_title'),
      subtitle: trans('auth.reset_password_subtitle'),
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
            trans('auth.password_reset_success'),
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
      'auth.reset_password',
      'header',
      context,
    );
    final footerSlot = MagicStarter.view.buildSlot(
      'auth.reset_password',
      'footer',
      context,
    );

    return MagicStarterAuthFormCard(
      title: trans('auth.reset_password_title'),
      subtitle: trans('auth.reset_password_subtitle'),
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
            // Email
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
                  _obscurePassword ? _iconVisible : _iconHidden,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              className: MagicStarter.formTheme.inputClassName,
              placeholderClassName: MagicStarter.formTheme.placeholderClassName,
              labelClassName: MagicStarter.formTheme.labelClassName,
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
                  () => _obscureConfirmation = !_obscureConfirmation,
                ),
                child: WIcon(
                  _obscureConfirmation ? _iconVisible : _iconHidden,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              className: MagicStarter.formTheme.inputClassName,
              placeholderClassName: MagicStarter.formTheme.placeholderClassName,
              labelClassName: MagicStarter.formTheme.labelClassName,
            ),
            const WSpacer(className: 'h-6'),

            // Submit
            WButton(
              isLoading: isLoading,
              onTap: _submit,
              className: MagicStarter.formTheme.primaryButtonClassName,
              child: WText(
                trans('auth.reset_password_button'),
                className: 'text-center',
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
